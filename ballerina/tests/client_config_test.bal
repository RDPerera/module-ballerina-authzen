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
isolated function testInvalidServiceUrls() {
    Client|error noScheme = new ("pdp.example.com");
    test:assertTrue(noScheme is error);
    Client|error withQuery = new ("https://pdp.example.com?tenant=1");
    test:assertTrue(withQuery is error);
    Client|error withFragment = new ("https://pdp.example.com#tenant");
    test:assertTrue(withFragment is error);
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
