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
isolated function testCredentialsReachDiscoveredEndpoint() returns error? {
    Client tenantPdp = check new (MOCK_URL + "/tenant1", auth = {token: "discovered-token"}, discoverEndpoints = true);
    Decision decision = check tenantPdp->evaluate({subject: alice, action: canRead, 'resource: {'type: "document", id: "doc-1"}});
    test:assertEquals(decision.context, {"authorization": "Bearer discovered-token"});
}

@test:Config {}
isolated function testHttpsPdpRejectsPlainHttpEndpoint() returns error? {
    GeneratedClient defaultClient = check new ({}, "https://pdp.example.com");
    ApiClient|error apiClient = toApiClient("http://pdp.example.com/eval", "access_evaluation_endpoint",
            EVALUATION_PATH, "https://pdp.example.com", defaultClient, {});
    if apiClient !is error {
        test:assertFail("Expected an error for a plain http endpoint of an https PDP");
    }
    test:assertTrue(apiClient.message().includes("'access_evaluation_endpoint'"));
    ApiClient|error mixedCase = toApiClient("HTTPS://pdp.example.com/eval", "access_evaluation_endpoint",
            EVALUATION_PATH, "https://pdp.example.com", defaultClient, {});
    test:assertTrue(mixedCase is http:Client);
}

@test:Config {}
isolated function testInvalidAdvertisedEndpoint() returns error? {
    GeneratedClient defaultClient = check new ({}, "http://pdp.example.com");
    ApiClient|error apiClient = toApiClient("/search/action", "search_action_endpoint", SEARCH_ACTION_PATH,
            "http://pdp.example.com", defaultClient, {});
    if apiClient !is error {
        test:assertFail("Expected an error for a relative endpoint URL");
    }
    test:assertEquals(apiClient.message(), "The PDP metadata advertises an invalid 'search_action_endpoint': '/search/action'");
}
