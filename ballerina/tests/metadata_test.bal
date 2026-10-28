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
isolated function testMetadataUrl() returns error? {
    test:assertEquals(check toMetadataUrl("https://pdp.example.com"),
            "https://pdp.example.com/.well-known/authzen-configuration");
    test:assertEquals(check toMetadataUrl("https://pdp.example.com:8443/tenant1"),
            "https://pdp.example.com:8443/.well-known/authzen-configuration/tenant1");
    test:assertEquals(check toMetadataUrl("http://localhost:9090/a/b"),
            "http://localhost:9090/.well-known/authzen-configuration/a/b");
    test:assertEquals(check toMetadataUrl("https://[::1]:8443/t"),
            "https://[::1]:8443/.well-known/authzen-configuration/t");
}
