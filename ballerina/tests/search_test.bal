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
