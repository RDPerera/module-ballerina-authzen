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
import ballerina/test;

final Client pdp = check new (MOCK_URL);

final readonly & Subject alice = {'type: "user", id: "alice@example.com"};
final readonly & Subject bob = {'type: "user", id: "bob@example.com"};
final readonly & Action canRead = {name: "can_read"};
final readonly & Action canWrite = {name: "can_write"};

@test:Config {}
isolated function testEvaluatePermit() returns error? {
    Decision result = check pdp->evaluate({
        subject: alice,
        action: canRead,
        'resource: {'type: "document", id: "doc-1"},
        context: {"time": "2026-10-28T10:00:00Z"}
    });
    test:assertTrue(result.decision);
    test:assertEquals(result.context, ());
}

@test:Config {}
isolated function testEvaluateDenyIsNotAnError() returns error? {
    Decision result = check pdp->evaluate({subject: bob, action: canWrite, 'resource: {'type: "document", id: "doc-1"}});
    test:assertFalse(result.decision);
}

@test:Config {}
isolated function testEvaluateSendsProperties() returns error? {
    Decision owner = check pdp->evaluate({
        subject: alice,
        action: canWrite,
        'resource: {'type: "document", id: "doc-1", properties: {"owner": "alice@example.com"}}
    });
    test:assertTrue(owner.decision);
    Decision other = check pdp->evaluate({
        subject: alice,
        action: canWrite,
        'resource: {'type: "document", id: "doc-2", properties: {"owner": "bob@example.com"}}
    });
    test:assertFalse(other.decision);
}

@test:Config {}
isolated function testEvaluateSendsRequestId() returns error? {
    Decision result = check pdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}},
        {requestId: "bfe9eb29-ab87-4ca3-be83-a1d5d8305716"});
    test:assertEquals(result.context, {"requestId": "bfe9eb29-ab87-4ca3-be83-a1d5d8305716"});
}

@test:Config {}
isolated function testEvaluateBadRequest() {
    Decision|error result = pdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "invalid", id: "x"}});
    if result !is http:ClientRequestError {
        test:assertFail("Expected an http:ClientRequestError");
    }
    test:assertEquals(result.detail().statusCode, 400);
    test:assertEquals(result.detail().body, "Unknown resource type");
}

@test:Config {}
isolated function testEvaluateServerError() {
    Decision|error result = pdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "broken", id: "x"}});
    if result !is http:RemoteServerError {
        test:assertFail("Expected an http:RemoteServerError");
    }
    test:assertEquals(result.detail().statusCode, 500);
}

@test:Config {}
isolated function testEvaluateBatchWithDefaults() returns error? {
    BatchEvaluationResponse result = check pdp->evaluateBatch({
        subject: bob,
        action: canRead,
        evaluations: [
            {'resource: {'type: "document", id: "doc-1"}},
            {'resource: {'type: "folder", id: "f-1"}},
            {action: canWrite, 'resource: {'type: "document", id: "doc-2"}},
            {subject: alice, 'resource: {'type: "folder", id: "f-1"}}
        ]
    });
    Decision[]? evaluations = result.evaluations;
    if evaluations is () {
        test:assertFail("Expected evaluations");
    }
    test:assertEquals(evaluations.map(d => d.decision), [true, false, false, true]);
}

@test:Config {}
isolated function testEvaluateBatchSemantics() returns error? {
    BatchEvaluationItem[] evaluations = [
        {'resource: {'type: "document", id: "doc-1"}},
        {'resource: {'type: "folder", id: "f-1"}},
        {'resource: {'type: "document", id: "doc-2"}}
    ];
    BatchEvaluationResponse all = check pdp->evaluateBatch({
        subject: bob,
        action: canRead,
        evaluations,
        options: {evaluationsSemantic: "execute_all"}
    });
    test:assertEquals((all.evaluations ?: []).length(), 3);

    BatchEvaluationResponse denyFirst = check pdp->evaluateBatch({
        subject: bob,
        action: canRead,
        evaluations,
        options: {evaluationsSemantic: "deny_on_first_deny"}
    });
    Decision[] denyDecisions = denyFirst.evaluations ?: [];
    test:assertEquals(denyDecisions.length(), 2);
    test:assertEquals(denyDecisions[1].context, {"reason": "deny_on_first_deny"});

    BatchEvaluationResponse permitFirst = check pdp->evaluateBatch({
        subject: bob,
        action: canRead,
        evaluations,
        options: {evaluationsSemantic: "permit_on_first_permit"}
    });
    test:assertEquals((permitFirst.evaluations ?: []).map(d => d.decision), [true]);
}

@test:Config {}
isolated function testEvaluateBatchWithoutEvaluations() returns error? {
    BatchEvaluationResponse result = check pdp->evaluateBatch({
        subject: alice,
        action: canRead,
        'resource: {'type: "document", id: "doc-1"}
    });
    test:assertEquals(result.decision, true);
    test:assertEquals(result.evaluations, ());
}

@test:Config {}
isolated function testSearchSubjects() returns error? {
    SubjectSearchResponse result = check pdp->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "document", id: "doc-1"}
    });
    test:assertEquals(result.results, [alice, bob]);
    test:assertEquals(result.page, ());
}

@test:Config {}
isolated function testSearchResourcesPaging() returns error? {
    ResourceSearchRequest request = {subject: alice, action: canRead, 'resource: {'type: "document"}, page: {'limit: 2}};
    ResourceSearchResponse first = check pdp->searchResources(request);
    test:assertEquals(first.results.map(r => r.id), ["doc-1", "doc-2"]);
    PageResponse? firstPage = first.page;
    if firstPage is () {
        test:assertFail("Expected a page");
    }
    test:assertEquals(firstPage, {nextToken: "2", count: 2, total: 3});

    ResourceSearchResponse second = check pdp->searchResources({
        subject: alice,
        action: canRead,
        'resource: {'type: "document"},
        page: {token: firstPage.nextToken, 'limit: 2}
    });
    test:assertEquals(second.results.map(r => r.id), ["doc-3"]);
    test:assertEquals(second.page?.nextToken, "");
}

@test:Config {}
isolated function testSearchActions() returns error? {
    ActionSearchResponse result = check pdp->searchActions({
        subject: alice,
        'resource: {'type: "document", id: "doc-1", properties: {"owner": "alice@example.com"}}
    });
    test:assertEquals(result.results, [canRead, canWrite]);
}

@test:Config {}
isolated function testGetMetadata() returns error? {
    Metadata metadata = check pdp->getMetadata();
    test:assertEquals(metadata.policyDecisionPoint, MOCK_URL);
    test:assertEquals(metadata.accessEvaluationEndpoint, MOCK_URL + "/access/v1/evaluation");
    test:assertEquals(metadata.searchActionEndpoint, MOCK_URL + "/access/v1/search/action");
    test:assertEquals(metadata.capabilities, ["urn:authzen:capability:example"]);
}

@test:Config {}
isolated function testGetMetadataOfPdpWithPath() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant1/");
    Metadata metadata = check tenantPdp->getMetadata();
    test:assertEquals(metadata.policyDecisionPoint, MOCK_URL + "/tenant1");
    test:assertEquals(metadata.accessEvaluationsEndpoint, ());
}

@test:Config {}
isolated function testGetMetadataRejectsOtherPdp() returns error? {
    Client mixupPdp = check new (MOCK_URL + "/mixup");
    Metadata|error metadata = mixupPdp->getMetadata();
    if metadata !is error {
        test:assertFail("Expected an error for metadata of another PDP");
    }
    test:assertTrue(metadata.message().includes("'https://pdp.attacker.example'"));
}

@test:Config {}
isolated function testGetMetadataNotPublished() returns error? {
    Client noMetadata = check new ("http://localhost:9091/secured");
    Metadata|error metadata = noMetadata->getMetadata();
    test:assertTrue(metadata is http:ClientRequestError);
}

@test:Config {}
isolated function testDiscoverDefaultEndpoints() returns error? {
    Client discovered = check new (MOCK_URL, discoverEndpoints = true);
    Decision decision = check discovered->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(decision.decision);
    BatchEvaluationResponse batch = check discovered->evaluateBatch({
        subject: alice,
        action: canRead,
        evaluations: [{'resource: {'type: "document", id: "doc-1"}}]
    });
    test:assertEquals((batch.evaluations ?: []).length(), 1);
    SubjectSearchResponse subjects = check discovered->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "document", id: "doc-1"}
    });
    test:assertEquals(subjects.results.length(), 2);
    ResourceSearchResponse resources = check discovered->searchResources({
        subject: bob,
        action: canRead,
        'resource: {'type: "document"}
    });
    test:assertEquals(resources.results.length(), 3);
    ActionSearchResponse actions = check discovered->searchActions({subject: bob, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(actions.results, [canRead]);
}

@test:Config {}
isolated function testDiscoverCustomEndpoints() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant1", discoverEndpoints = true);
    // The Access Evaluation API is served at a custom URL, which a default-path client can't reach.
    Decision decision = check tenantPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}},
        {requestId: "req-1"});
    test:assertTrue(decision.decision);
    test:assertEquals(decision.context, {"requestId": "req-1"});
    SubjectSearchResponse subjects = check tenantPdp->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "document", id: "doc-1"},
        page: {'limit: 1}
    });
    test:assertEquals(subjects.results, [alice]);
    test:assertEquals(subjects.page?.nextToken, "1");

    Client defaultPaths = check new (MOCK_URL + "/tenant1");
    Decision|error notFound = defaultPaths->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(notFound is http:ClientRequestError);
}

@test:Config {}
isolated function testDiscoverCustomSearchAndBatchEndpoints() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant2", discoverEndpoints = true);
    Decision decision = check tenantPdp->evaluate({subject: bob, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(decision.decision);
    BatchEvaluationResponse batch = check tenantPdp->evaluateBatch({
        subject: bob,
        action: canRead,
        evaluations: [{'resource: {'type: "document", id: "doc-1"}}, {'resource: {'type: "folder", id: "f-1"}}],
        options: {evaluationsSemantic: "deny_on_first_deny"}
    });
    test:assertEquals((batch.evaluations ?: []).map(d => d.decision), [true, false]);
    ResourceSearchResponse resources = check tenantPdp->searchResources({
        subject: alice,
        action: canRead,
        'resource: {'type: "document"},
        page: {'limit: 2, token: "2"}
    });
    test:assertEquals(resources.results.map(r => r.id), ["doc-3"]);
    test:assertEquals(resources.page?.nextToken, "");
    ActionSearchResponse actions = check tenantPdp->searchActions({subject: bob, 'resource: {'type: "folder", id: "f-1"}});
    test:assertEquals(actions.results, []);
}

@test:Config {}
isolated function testDiscoveredUnsupportedApis() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant1", discoverEndpoints = true);
    BatchEvaluationResponse|error batch = tenantPdp->evaluateBatch({subject: alice, action: canRead, evaluations: []});
    if batch !is error {
        test:assertFail("Expected an error for an API the PDP doesn't support");
    }
    test:assertEquals(batch.message(),
            "The PDP doesn't support the Access Evaluations API: its metadata has no 'access_evaluations_endpoint'");
    ResourceSearchResponse|error resources = tenantPdp->searchResources({
        subject: alice,
        action: canRead,
        'resource: {'type: "document"}
    });
    test:assertTrue(resources is error);
    ActionSearchResponse|error actions = tenantPdp->searchActions({subject: alice, 'resource: {'type: "document", id: "d"}});
    test:assertTrue(actions is error);

    Client tenant2 = check new (MOCK_URL + "/tenant2", discoverEndpoints = true);
    SubjectSearchResponse|error subjects = tenant2->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "document", id: "doc-1"}
    });
    if subjects !is error {
        test:assertFail("Expected an error for an API the PDP doesn't support");
    }
    test:assertEquals(subjects.message(),
            "The PDP doesn't support the Subject Search API: its metadata has no 'search_subject_endpoint'");
}

@test:Config {}
isolated function testDiscoveryFailsForOtherPdp() {
    Client|error mixupPdp = new (MOCK_URL + "/mixup", discoverEndpoints = true);
    test:assertTrue(mixupPdp is error);
}

@test:Config {}
isolated function testDiscoveryFailsWithoutMetadata() {
    Client|error noMetadata = new ("http://localhost:9091/secured", discoverEndpoints = true);
    test:assertTrue(noMetadata is http:ClientRequestError);
}

@test:Config {}
isolated function testBearerToken() returns error? {
    Client secured = check new ("http://localhost:9091/secured", auth = {token: "valid-token"});
    Decision decision = check secured->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(decision.decision);
    test:assertEquals(decision.context, {"authorization": "Bearer valid-token"});
}

@test:Config {}
isolated function testUnauthenticated() returns error? {
    Client secured = check new ("http://localhost:9091/secured");
    Decision|error decision = secured->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    if decision !is http:ClientRequestError {
        test:assertFail("Expected an http:ClientRequestError");
    }
    test:assertEquals(decision.detail().statusCode, 401);
}

@test:Config {}
isolated function testOAuth2ClientCredentials() returns error? {
    Client oauthPdp = check new (MOCK_URL, auth = {
        tokenUrl: MOCK_URL + "/oauth2/token",
        clientId: "client-id",
        clientSecret: "client-secret"
    });
    Decision decision = check oauthPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(decision.context, {"authorization": "Bearer oauth-access-token"});
}

@test:Config {}
isolated function testBasicAuth() returns error? {
    Client basicPdp = check new (MOCK_URL, auth = {username: "pep", password: "pep-secret"});
    Decision decision = check basicPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(decision.context, {"authorization": "Basic cGVwOnBlcC1zZWNyZXQ="});
}

@test:Config {}
isolated function testApiKeyInAuthorizationHeader() returns error? {
    Client apiKeyPdp = check new (MOCK_URL, auth = {apiKey: "basic my-api-key"});
    Decision decision = check apiKeyPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}},
        {requestId: "req-2"});
    test:assertEquals(decision.context, {"authorization": "basic my-api-key", "requestId": "req-2"});
}

@test:Config {}
isolated function testApiKeyInCustomHeader() returns error? {
    Client apiKeyPdp = check new (MOCK_URL, auth = {apiKey: "my-api-key", headerName: "X-API-Key"}, discoverEndpoints = true);
    Decision decision = check apiKeyPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(decision.context, {"apiKey": "my-api-key"});

    Client tenantPdp = check new (MOCK_URL + "/tenant1", auth = {apiKey: "my-api-key", headerName: "X-API-Key"},
        discoverEndpoints = true);
    Decision custom = check tenantPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(custom.context, {"apiKey": "my-api-key"});
}

@test:Config {}
isolated function testEmptyApiKeyHeaderName() {
    Client|error apiKeyPdp = new (MOCK_URL, auth = {apiKey: "my-api-key", headerName: " "});
    if apiKeyPdp !is error {
        test:assertFail("Expected an error for an empty header name");
    }
    test:assertEquals(apiKeyPdp.message(), "`auth.headerName` must not be empty");
}

@test:Config {}
isolated function testInvalidServiceUrls() {
    Client|error noScheme = new ("pdp.example.com");
    test:assertTrue(noScheme is error);
    Client|error withQuery = new ("https://pdp.example.com?tenant=1");
    test:assertTrue(withQuery is error);
    Client|error withFragment = new ("https://pdp.example.com#tenant");
    test:assertTrue(withFragment is error);
}

@test:Config {}
isolated function testMetadataUrl() returns error? {
    test:assertEquals(check toMetadataUrl("https://pdp.example.com"),
            "https://pdp.example.com/.well-known/authzen-configuration");
    test:assertEquals(check toMetadataUrl("https://pdp.example.com:8443/tenant1"),
            "https://pdp.example.com:8443/.well-known/authzen-configuration/tenant1");
    test:assertEquals(check toMetadataUrl("http://localhost:9090/a/b"),
            "http://localhost:9090/.well-known/authzen-configuration/a/b");
}

@test:Config {}
isolated function testHttpSettingsAreApplied() returns error? {
    Client configured = check new (MOCK_URL,
        httpVersion = http:HTTP_1_1,
        timeout = 10,
        followRedirects = {enabled: true, maxCount: 3},
        poolConfig = {maxActiveConnections: 10},
        circuitBreaker = {rollingWindow: {timeWindow: 10, bucketSize: 2}, failureThreshold: 0.5, resetTime: 5, statusCodes: [500]},
        retryConfig = {count: 2, interval: 1},
        cookieConfig = {enabled: true},
        secureSocket = {enable: false},
        proxy = {host: "localhost", port: 3128},
        discoverEndpoints = false
    );
    // The proxy isn't running, so the call fails, which shows the setting reached the HTTP client.
    Decision|error decision = configured->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(decision is error);

    Client direct = check new (MOCK_URL,
        httpVersion = http:HTTP_1_1,
        followRedirects = {enabled: true, maxCount: 3},
        poolConfig = {maxActiveConnections: 10},
        retryConfig = {count: 2, interval: 1},
        cookieConfig = {enabled: true}
    );
    Decision permitted = check direct->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertTrue(permitted.decision);
}

@test:Config {}
isolated function testDiscoverCustomSubjectSearchEndpoint() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant3", discoverEndpoints = true);
    SubjectSearchResponse subjects = check tenantPdp->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "folder", id: "f-1"}
    }, {requestId: "req-3"});
    test:assertEquals(subjects.results, [alice]);
}

@test:Config {}
isolated function testGeneratedClient() returns error? {
    GeneratedClient generated = check new ({}, MOCK_URL);
    Metadata metadata = check generated->getMetadata();
    test:assertEquals(metadata.policyDecisionPoint, MOCK_URL);
    EvaluationRequest request = {subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}};
    Decision decision = check generated->evaluate(request);
    test:assertTrue(decision.decision);
    BatchEvaluationResponse batch = check generated->evaluateBatch({...request});
    test:assertEquals(batch.decision, true);
    SubjectSearchResponse subjects = check generated->searchSubjects({
        subject: {'type: "user"},
        action: canRead,
        'resource: {'type: "document", id: "doc-1"}
    });
    test:assertEquals(subjects.results.length(), 2);
    ResourceSearchResponse resources = check generated->searchResources({
        subject: alice,
        action: canRead,
        'resource: {'type: "document"}
    });
    test:assertEquals(resources.results.length(), 3);
    ActionSearchResponse actions = check generated->searchActions({subject: bob, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(actions.results, [canRead]);
}

const ECHO_URL = "http://localhost:9092";

@test:Config {}
isolated function testWireFormatOfEvaluate() returns error? {
    Client echoPdp = check new (ECHO_URL);
    Decision decision = check echoPdp->evaluate({
        subject: {'type: "user", id: "alice@example.com", properties: {"department": "Sales", "groups": ["a", "b"]}},
        action: {name: "can_read", properties: {"method": "GET"}},
        'resource: {'type: "account", id: "123", properties: {"library_record": {"isbn": "978-0593383322"}}},
        context: {"time": "1985-10-26T01:22-07:00", "score": 0.75, "flag": true}
    });
    // Compared as JSON text: the PDP returns `0.75` as a decimal, while the request sent a float.
    test:assertEquals((decision.context ?: {}).toJsonString(), {
        "body": {
            "subject": {"type": "user", "id": "alice@example.com", "properties": {"department": "Sales", "groups": ["a", "b"]}},
            "action": {"name": "can_read", "properties": {"method": "GET"}},
            "resource": {"type": "account", "id": "123", "properties": {"library_record": {"isbn": "978-0593383322"}}},
            "context": {"time": "1985-10-26T01:22-07:00", "score": 0.75, "flag": true}
        },
        "contentType": "application/json"
    }.toJsonString());
}

@test:Config {}
isolated function testWireFormatOfEvaluateBatch() returns error? {
    Client echoPdp = check new (ECHO_URL);
    BatchEvaluationResponse response = check echoPdp->evaluateBatch({
        subject: {'type: "user", id: "alice@example.com"},
        context: {"time": "2024-05-31T15:22-07:00"},
        evaluations: [
            {action: {name: "can_read"}, 'resource: {'type: "document", id: "boxcarring.md"}},
            {action: {name: "can_edit"}, 'resource: {'type: "document", id: "resource-search.md"}}
        ],
        options: {evaluationsSemantic: "deny_on_first_deny", "another_option": "value"}
    });
    Decision[] evaluations = response.evaluations ?: [];
    test:assertEquals(evaluations[0].context, {
        "body": {
            "subject": {"type": "user", "id": "alice@example.com"},
            "context": {"time": "2024-05-31T15:22-07:00"},
            "evaluations": [
                {"action": {"name": "can_read"}, "resource": {"type": "document", "id": "boxcarring.md"}},
                {"action": {"name": "can_edit"}, "resource": {"type": "document", "id": "resource-search.md"}}
            ],
            "options": {"evaluations_semantic": "deny_on_first_deny", "another_option": "value"}
        },
        "contentType": "application/json"
    });
}

@test:Config {}
isolated function testWireFormatOfSearches() returns error? {
    Client echoPdp = check new (ECHO_URL);
    SubjectSearchResponse subjects = check echoPdp->searchSubjects({
        subject: {'type: "user"},
        action: {name: "can_read"},
        'resource: {'type: "account", id: "123"},
        page: {token: "a3M9NDU2O3N6PTI=", 'limit: 2, properties: {"sort": "id"}}
    });
    test:assertEquals(subjects.context, {
        "body": {
            "subject": {"type": "user"},
            "action": {"name": "can_read"},
            "resource": {"type": "account", "id": "123"},
            "page": {"token": "a3M9NDU2O3N6PTI=", "limit": 2, "properties": {"sort": "id"}}
        },
        "contentType": "application/json"
    });
    test:assertEquals(subjects.page?.nextToken, "");
    ResourceSearchResponse resources = check echoPdp->searchResources({
        subject: {'type: "user", id: "alice@example.com"},
        action: {name: "can_read"},
        'resource: {'type: "account"}
    });
    test:assertEquals(resources.context, {
        "body": {
            "subject": {"type": "user", "id": "alice@example.com"},
            "action": {"name": "can_read"},
            "resource": {"type": "account"}
        },
        "contentType": "application/json"
    });
    ActionSearchResponse actions = check echoPdp->searchActions({
        subject: {'type: "user", id: "alice@example.com"},
        'resource: {'type: "account", id: "123"}
    });
    test:assertEquals(actions.context, {
        "body": {"subject": {"type": "user", "id": "alice@example.com"}, "resource": {"type": "account", "id": "123"}},
        "contentType": "application/json"
    });
}

@test:Config {}
isolated function testUnicodeIdentifiers() returns error? {
    Client echoPdp = check new (ECHO_URL);
    Decision decision = check echoPdp->evaluate({
        subject: {'type: "user", id: "ダイラン@例え.jp"},
        action: {name: "läsa"},
        'resource: {'type: "doc", id: "\"quoted\" / slash \\ emoji 🚀"}
    }, {requestId: "req-ü"});
    json body = check (decision.context ?: {}).toJson().body;
    test:assertEquals(check body.subject.id, "ダイラン@例え.jp");
    test:assertEquals(check body.'resource.id, "\"quoted\" / slash \\ emoji 🚀");
}

@test:Config {}
isolated function testLargeBatch() returns error? {
    BatchEvaluationItem[] evaluations = [];
    foreach int i in 0 ..< 500 {
        evaluations.push({'resource: {'type: i % 2 == 0 ? "document" : "folder", id: i.toString()}});
    }
    BatchEvaluationResponse response = check pdp->evaluateBatch({subject: bob, action: canRead, evaluations});
    Decision[] decisions = response.evaluations ?: [];
    test:assertEquals(decisions.length(), 500);
    foreach int i in 0 ..< 500 {
        test:assertEquals(decisions[i].decision, i % 2 == 0);
    }
}

@test:Config {}
function testConcurrentCalls() returns error? {
    future<Decision|error>[] calls = [];
    foreach int i in 0 ..< 100 {
        Subject subject = i % 2 == 0 ? alice : bob;
        future<Decision|error> call = start pdp->evaluate({subject, action: canWrite, 'resource: {'type: "document", id: i.toString(), properties: {"owner": "alice@example.com"}}},
            {requestId: i.toString()});
        calls.push(call);
    }
    foreach int i in 0 ..< 100 {
        Decision decision = check wait calls[i];
        test:assertEquals(decision.decision, i % 2 == 0);
        test:assertEquals(decision.context, {"requestId": i.toString()});
    }
}
