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
