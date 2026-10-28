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
