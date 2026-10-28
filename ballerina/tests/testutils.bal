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

final Client pdp = check new (MOCK_URL);

final readonly & Subject alice = {'type: "user", id: "alice@example.com"};
final readonly & Subject bob = {'type: "user", id: "bob@example.com"};
final readonly & Action canRead = {name: "can_read"};
final readonly & Action canWrite = {name: "can_write"};

const ECHO_URL = "http://localhost:9092";
