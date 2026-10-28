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

// This example reviews who can do what with the records of a company, against the "search" scenario of the AuthZEN
// interoperability tests. It lists the users who may delete a record, then the records a user may delete, page by
// page, and finally the actions the user may perform on one record.

import ballerina/authzen;
import ballerina/io;

configurable string pdpUrl = "https://authzen-proxy-demo.cerbos.dev";

public function main() returns error? {
    authzen:Client pdp = check new (pdpUrl, discoverEndpoints = true);

    // Step 1: Who may delete record 102? Only the subject type is set; the PDP finds the IDs.
    authzen:SubjectSearchResponse subjects = check pdp->searchSubjects({
        subject: {'type: "user"},
        action: {name: "delete"},
        'resource: {'type: "record", id: "102"}
    });
    io:println("Users who may delete record 102: ", subjects.results.map(s => s.id));

    // Step 2: Which records may bob delete? Read the results two at a time, sending each page's token back
    // with an otherwise unchanged request until the token is empty.
    string[] records = [];
    string? cursor = ();
    while true {
        authzen:PageRequest page = {'limit: 2};
        if cursor is string {
            page.token = cursor;
        }
        authzen:ResourceSearchResponse resources = check pdp->searchResources({
            subject: {'type: "user", id: "bob"},
            action: {name: "delete"},
            'resource: {'type: "record"},
            page
        });
        records.push(...resources.results.map(r => r.id));
        string nextCursor = resources.page?.nextToken ?: "";
        // Stop at the last page, and also if the PDP returns the same token again, which would never end.
        if nextCursor == "" || nextCursor == cursor {
            break;
        }
        cursor = nextCursor;
    }
    io:println("Records bob may delete: ", records);

    // Step 3: What may bob do with record 102?
    authzen:ActionSearchResponse actions = check pdp->searchActions({
        subject: {'type: "user", id: "bob"},
        'resource: {'type: "record", id: "102"}
    });
    io:println("Actions bob may perform on record 102: ", actions.results.map(a => a.name));
}
