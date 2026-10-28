// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/http;

const MOCK_PORT = 9090;
const MOCK_URL = "http://localhost:9090";

// A mock PDP. Policy: `alice@example.com` may `can_read` any resource and `can_write` documents she owns
// (resource property `owner`); `bob@example.com` may `can_read` documents only. A resource of type `invalid` makes
// the PDP fail the request with 400, and one of type `broken` with 500.
//
// Each decision's context echoes the `Authorization` and `X-Request-ID` headers the PDP received, so the tests can
// check what the client sent.

final string[] & readonly USERS = ["alice@example.com", "bob@example.com", "carol@example.com"];
final string[] & readonly DOCUMENTS = ["doc-1", "doc-2", "doc-3"];

isolated function isPermitted(json subject, json action, json 'resource) returns boolean|error {
    string subjectId = check subject.id;
    string actionName = check action.name;
    string resourceType = check 'resource.'type;
    if subjectId == "alice@example.com" {
        if actionName == "can_read" {
            return true;
        }
        if actionName == "can_write" {
            json|error owner = 'resource.properties.owner;
            return owner == subjectId;
        }
        return false;
    }
    return subjectId == "bob@example.com" && actionName == "can_read" && resourceType == "document";
}

isolated function decide(json subject, json action, json 'resource, http:Request request) returns json|error {
    boolean decision = check isPermitted(subject, action, 'resource);
    map<json> context = {};
    string|http:HeaderNotFoundError authorization = request.getHeader("Authorization");
    if authorization is string {
        context["authorization"] = authorization;
    }
    string|http:HeaderNotFoundError apiKey = request.getHeader("X-API-Key");
    if apiKey is string {
        context["apiKey"] = apiKey;
    }
    string|http:HeaderNotFoundError requestId = request.getHeader("X-Request-ID");
    if requestId is string {
        context["requestId"] = requestId;
    }
    return context.length() == 0 ? {decision} : {decision, context};
}

isolated function failure(json 'resource) returns http:Response? {
    json|error resourceType = 'resource.'type;
    if resourceType == "invalid" {
        http:Response response = new;
        response.statusCode = 400;
        response.setTextPayload("Unknown resource type");
        return response;
    }
    if resourceType == "broken" {
        http:Response response = new;
        response.statusCode = 500;
        response.setTextPayload("Policy engine unavailable");
        return response;
    }
    return ();
}

isolated function respond(json body, http:Request request) returns http:Response {
    http:Response response = new;
    response.setJsonPayload(body);
    string|http:HeaderNotFoundError requestId = request.getHeader("X-Request-ID");
    if requestId is string {
        response.setHeader("X-Request-ID", requestId);
    }
    return response;
}

isolated function evaluateOne(http:Request request) returns http:Response|error {
    json body = check request.getJsonPayload();
    json subject = check body.subject;
    json action = check body.action;
    json 'resource = check body.'resource;
    http:Response? failed = failure('resource);
    if failed is http:Response {
        return failed;
    }
    return respond(check decide(subject, action, 'resource, request), request);
}

isolated function evaluateMany(http:Request request) returns http:Response|error {
    map<json> body = check (check request.getJsonPayload()).ensureType();
    json[] evaluations = body.hasKey("evaluations") ? check body.get("evaluations").ensureType() : [];
    if evaluations.length() == 0 {
        return evaluateOne(request);
    }
    json|error semantic = body.options.evaluations_semantic;
    json[] decisions = [];
    foreach json entry in evaluations {
        map<json> item = check entry.ensureType();
        json subject = item.hasKey("subject") ? item.get("subject") : body.get("subject");
        json action = item.hasKey("action") ? item.get("action") : body.get("action");
        json 'resource = item.hasKey("resource") ? item.get("resource") : body.get("resource");
        map<json> decision = check (check decide(subject, action, 'resource, request)).ensureType();
        decisions.push(decision);
        boolean permitted = check decision.get("decision").ensureType();
        if semantic == "deny_on_first_deny" && !permitted {
            decision["context"] = {reason: "deny_on_first_deny"};
            break;
        }
        if semantic == "permit_on_first_permit" && permitted {
            break;
        }
    }
    return respond({evaluations: decisions}, request);
}

// Pages through `items` two at a time when the request sets `page.limit`, using the offset as the token.
isolated function page(json body, json[] items, http:Request request) returns http:Response|error {
    json|error 'limit = body.page.'limit;
    if 'limit !is int {
        return respond({results: items}, request);
    }
    json|error token = body.page.token;
    int offset = token is string ? check int:fromString(token) : 0;
    int end = int:min(offset + 'limit, items.length());
    string nextToken = end < items.length() ? end.toString() : "";
    return respond({
                       page: {next_token: nextToken, count: end - offset, total: items.length()},
                       results: items.slice(offset, end)
                   }, request);
}

isolated function searchSubjects(http:Request request) returns http:Response|error {
    json body = check request.getJsonPayload();
    string subjectType = check body.subject.'type;
    json[] results = [];
    if subjectType == "user" {
        foreach string id in USERS {
            if check isPermitted({'type: "user", id}, check body.action, check body.'resource) {
                results.push({'type: "user", id});
            }
        }
    }
    return page(body, results, request);
}

isolated function searchResources(http:Request request) returns http:Response|error {
    json body = check request.getJsonPayload();
    string resourceType = check body.'resource.'type;
    json[] results = [];
    foreach string id in DOCUMENTS {
        json 'resource = {'type: resourceType, id};
        if check isPermitted(check body.subject, check body.action, 'resource) {
            results.push('resource);
        }
    }
    return page(body, results, request);
}

isolated function searchActions(http:Request request) returns http:Response|error {
    json body = check request.getJsonPayload();
    json[] results = [];
    foreach string name in ["can_read", "can_write", "can_delete"] {
        if check isPermitted(check body.subject, {name}, check body.'resource) {
            results.push({name});
        }
    }
    return page(body, results, request);
}

isolated function metadata(string policyDecisionPoint) returns json => {
    policy_decision_point: policyDecisionPoint,
    access_evaluation_endpoint: policyDecisionPoint + "/access/v1/evaluation",
    access_evaluations_endpoint: policyDecisionPoint + "/access/v1/evaluations",
    search_subject_endpoint: policyDecisionPoint + "/access/v1/search/subject",
    search_resource_endpoint: policyDecisionPoint + "/access/v1/search/resource",
    search_action_endpoint: policyDecisionPoint + "/access/v1/search/action",
    capabilities: ["urn:authzen:capability:example"],
    "unknown_parameter": "ignored"
};

service / on new http:Listener(MOCK_PORT) {

    // PDP `http://localhost:9090`, which serves every API at its default path.
    resource function get \.well\-known/authzen\-configuration() returns json => metadata(MOCK_URL);

    resource function post access/v1/evaluation(http:Request request) returns http:Response|error =>
        evaluateOne(request);

    resource function post access/v1/evaluations(http:Request request) returns http:Response|error =>
        evaluateMany(request);

    resource function post access/v1/search/subject(http:Request request) returns http:Response|error =>
        searchSubjects(request);

    resource function post access/v1/search/'resource(http:Request request) returns http:Response|error =>
        searchResources(request);

    resource function post access/v1/search/action(http:Request request) returns http:Response|error =>
        searchActions(request);

    // PDP `http://localhost:9090/tenant1`. Its metadata advertises the Access Evaluation API at a custom URL, the
    // Subject Search API at its default path and no other API.
    resource function get \.well\-known/authzen\-configuration/tenant1() returns json => {
        policy_decision_point: MOCK_URL + "/tenant1",
        access_evaluation_endpoint: MOCK_URL + "/pdp/tenant1/check",
        search_subject_endpoint: MOCK_URL + "/tenant1/access/v1/search/subject"
    };

    resource function post pdp/tenant1/'check(http:Request request) returns http:Response|error =>
        evaluateOne(request);

    resource function post tenant1/access/v1/search/subject(http:Request request) returns http:Response|error =>
        searchSubjects(request);

    // PDP `http://localhost:9090/tenant2`. Its metadata advertises the Access Evaluations and Action Search APIs at
    // custom URLs, and the search URL on the default path of another PDP.
    resource function get \.well\-known/authzen\-configuration/tenant2() returns json => {
        policy_decision_point: MOCK_URL + "/tenant2/",
        access_evaluation_endpoint: MOCK_URL + "/tenant2/access/v1/evaluation",
        access_evaluations_endpoint: MOCK_URL + "/pdp/tenant2/batch",
        search_resource_endpoint: MOCK_URL + "/pdp/tenant2/resources",
        search_action_endpoint: MOCK_URL + "/pdp/tenant2/actions"
    };

    resource function post tenant2/access/v1/evaluation(http:Request request) returns http:Response|error =>
        evaluateOne(request);

    resource function post pdp/tenant2/batch(http:Request request) returns http:Response|error =>
        evaluateMany(request);

    resource function post pdp/tenant2/resources(http:Request request) returns http:Response|error =>
        searchResources(request);

    resource function post pdp/tenant2/actions(http:Request request) returns http:Response|error =>
        searchActions(request);

    // PDP `http://localhost:9090/tenant3`, which serves the Subject Search API at a custom URL.
    resource function get \.well\-known/authzen\-configuration/tenant3() returns json => {
        policy_decision_point: MOCK_URL + "/tenant3",
        access_evaluation_endpoint: MOCK_URL + "/tenant3/access/v1/evaluation",
        search_subject_endpoint: MOCK_URL + "/pdp/tenant3/subjects"
    };

    resource function post pdp/tenant3/subjects(http:Request request) returns http:Response|error =>
        searchSubjects(request);

    // PDP `http://localhost:9090/mixup`, whose metadata names another PDP.
    resource function get \.well\-known/authzen\-configuration/mixup() returns json =>
        metadata("https://pdp.attacker.example");

    // OAuth 2.0 token endpoint for the client credentials grant.
    resource function post oauth2/token(http:Request request) returns json|http:Unauthorized|error {
        string authorization = check request.getHeader("Authorization");
        if authorization != "Basic Y2xpZW50LWlkOmNsaWVudC1zZWNyZXQ=" {
            return http:UNAUTHORIZED;
        }
        return {access_token: "oauth-access-token", token_type: "Bearer", expires_in: 3600};
    }
}

// A PDP at `http://localhost:9092` that permits everything and returns the request body it received, and the
// headers it received, in the context, so the tests can check the exact JSON the client sends. Its responses also
// carry members AuthZEN doesn't define, which a client must ignore.
service / on new http:Listener(9092) {
    resource function post access/v1/[string... api](http:Request request) returns json|error {
        json body = check request.getJsonPayload();
        string|http:HeaderNotFoundError contentType = request.getHeader("Content-Type");
        json received = {body, contentType: contentType is string ? contentType : ()};
        if api == ["evaluations"] {
            return {evaluations: [{decision: true, context: received, "extension": 1}], "extension": {"a": 1}};
        }
        if api[0] == "search" {
            return {results: [], context: received, page: {next_token: "", "cursor_hint": "x"}, "extension": true};
        }
        return {decision: true, context: received, "extension": "ignored"};
    }
}

// A PDP that requires a Bearer token and publishes no metadata.
service /secured on new http:Listener(9091) {
    resource function post access/v1/evaluation(http:Request request) returns http:Response|error {
        string|http:HeaderNotFoundError authorization = request.getHeader("Authorization");
        if authorization != "Bearer valid-token" {
            http:Response response = new;
            response.statusCode = 401;
            response.setHeader("WWW-Authenticate", "Bearer");
            response.setTextPayload("Missing or invalid access token");
            return response;
        }
        return evaluateOne(request);
    }
}
