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

// This example checks what the users of a shared todo app may do, against the "todo" scenario of the AuthZEN
// interoperability tests. It asks one question with `evaluate`, then asks for every user and action at once with
// `evaluateBatch`, which sends the shared resource once and each user and action as a batch entry.

import ballerina/authzen;
import ballerina/io;

configurable string pdpUrl = "https://authzen-proxy-demo.cerbos.dev";

// Users of the todo app, identified by the subject IDs of the interop scenario.
final map<string> & readonly users = {
    "Rick": "CiRmZDA2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs",
    "Morty": "CiRmZDE2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs",
    "Beth": "CiRmZDM2MTRkMy1jMzlhLTQ3ODEtYjdiZC04Yjk2ZjVhNTEwMGQSBWxvY2Fs"
};
final string[] & readonly actions = ["can_read_todos", "can_create_todo"];

public function main() returns error? {
    authzen:Client pdp = check new (pdpUrl);

    // Step 1: Ask one question: may Beth create a todo?
    authzen:Decision decision = check pdp->evaluate({
        subject: {'type: "user", id: users.get("Beth")},
        action: {name: "can_create_todo"},
        'resource: {'type: "todo", id: "todo-1"}
    }, {requestId: "todo-check-1"});
    io:println(string `Beth may create a todo: ${decision.decision}`);

    // Step 2: Ask for every user and action in one call. The resource is a default shared by all entries.
    authzen:BatchEvaluationItem[] evaluations = [];
    [string, string][] questions = [];
    foreach [string, string] [name, id] in users.entries() {
        foreach string action in actions {
            evaluations.push({subject: {'type: "user", id}, action: {name: action}});
            questions.push([name, action]);
        }
    }
    authzen:BatchEvaluationResponse response = check pdp->evaluateBatch({
        'resource: {'type: "todo", id: "todo-1"},
        evaluations
    });

    // The decisions come back in the order of the entries.
    authzen:Decision[] decisions = response.evaluations ?: [];
    foreach int i in 0 ..< decisions.length() {
        [string, string] [name, action] = questions[i];
        io:println(string `${name} ${action}: ${decisions[i].decision ? "permit" : "deny"}`);
    }
}
