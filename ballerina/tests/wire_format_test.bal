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

import ballerina/test;

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
