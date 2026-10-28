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

import ballerina/os;
import ballerina/test;

// Live tests against a PDP of the AuthZEN interop (https://authzen-interop.net). The evaluation APIs serve the
// "todo" scenario (Rick, Morty, Summer, Beth and Jerry) and the search APIs the "search" scenario (users `alice` to
// `felix` and records `101` to `120`). Every call only reads decisions.
configurable boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
configurable string livePdpUrl = os:getEnv("AUTHZEN_PDP_URL") == "" ? "https://authzen-proxy-demo.cerbos.dev"
    : os:getEnv("AUTHZEN_PDP_URL");

const RICK = "CiRmZDA2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs";
const MORTY = "CiRmZDE2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs";
const BETH = "CiRmZDM2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs";

@test:Config {groups: ["live_tests"], enable: isLiveServer}
isolated function testLiveMetadata() returns error? {
    Client live = check new (livePdpUrl);
    Metadata metadata = check live->getMetadata();
    test:assertEquals(metadata.policyDecisionPoint, livePdpUrl);
    test:assertEquals(metadata.accessEvaluationEndpoint, livePdpUrl + "/access/v1/evaluation");
}

@test:Config {groups: ["live_tests"], enable: isLiveServer}
isolated function testLiveEvaluate() returns error? {
    Client live = check new (livePdpUrl);
    // Rick is an admin and may create todos; Beth is a viewer and may not.
    Decision permit = check live->evaluate({
        subject: {'type: "user", id: RICK},
        action: {name: "can_create_todo"},
        'resource: {'type: "todo", id: "todo-1"}
    }, {requestId: "live-evaluate-1"});
    test:assertTrue(permit.decision);
    Decision deny = check live->evaluate({
        subject: {'type: "user", id: BETH},
        action: {name: "can_create_todo"},
        'resource: {'type: "todo", id: "todo-1"}
    });
    test:assertFalse(deny.decision);
}

@test:Config {groups: ["live_tests"], enable: isLiveServer}
isolated function testLiveEvaluateBatch() returns error? {
    Client live = check new (livePdpUrl, discoverEndpoints = true);
    BatchEvaluationResponse result = check live->evaluateBatch({
        action: {name: "can_create_todo"},
        'resource: {'type: "todo", id: "todo-1"},
        evaluations: [
            {subject: {'type: "user", id: RICK}},
            {subject: {'type: "user", id: BETH}},
            {subject: {'type: "user", id: MORTY}},
            {subject: {'type: "user", id: BETH}, action: {name: "can_read_todos"}}
        ]
    });
    test:assertEquals((result.evaluations ?: []).map(d => d.decision), [true, false, true, true]);
}

@test:Config {groups: ["live_tests"], enable: isLiveServer}
isolated function testLiveSearches() returns error? {
    Client live = check new (livePdpUrl, discoverEndpoints = true);
    SubjectSearchResponse subjects = check live->searchSubjects({
        subject: {'type: "user"},
        action: {name: "delete"},
        'resource: {'type: "record", id: "102"}
    });
    test:assertTrue(subjects.results.some(s => s.id == "bob"));

    ResourceSearchResponse firstPage = check live->searchResources({
        subject: {'type: "user", id: "bob"},
        action: {name: "delete"},
        'resource: {'type: "record"},
        page: {'limit: 2}
    });
    test:assertEquals(firstPage.results.length(), 2);
    string nextToken = firstPage.page?.nextToken ?: "";
    test:assertNotEquals(nextToken, "");
    ResourceSearchResponse secondPage = check live->searchResources({
        subject: {'type: "user", id: "bob"},
        action: {name: "delete"},
        'resource: {'type: "record"},
        page: {'limit: 2, token: nextToken}
    });
    test:assertTrue(secondPage.results.length() > 0);
    string[] firstIds = firstPage.results.map(r => r.id);
    foreach Resource r in secondPage.results {
        test:assertTrue(firstIds.indexOf(r.id) is (), "A record appears on both pages: " + r.id);
    }

    ActionSearchResponse actions = check live->searchActions({
        subject: {'type: "user", id: "bob"},
        'resource: {'type: "record", id: "102"}
    });
    test:assertTrue(actions.results.some(a => a.name == "delete"));
}
