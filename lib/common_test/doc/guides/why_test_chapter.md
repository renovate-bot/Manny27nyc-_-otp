<!--
%CopyrightBegin%

SPDX-License-Identifier: Apache-2.0

Copyright Ericsson AB 2023-2025. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

%CopyrightEnd%
-->
# Some Thoughts about Testing

## Goals

It is not possible to prove that a program is correct by testing. On the
contrary, it has been formally proven that it is impossible to prove programs in
general by testing. Theoretical program proofs or plain examination of code can
be viable options for those wishing to certify that a program is correct. The
test server, as it is based on testing, cannot be used for certification. Its
intended use is instead to (cost effectively) _find bugs_. A successful test
suite is one that reveals a bug. If a test suite results in OK, then we know
very little that we did not know before.

## What to Test

There are many kinds of test suites. Some concentrate on calling every function
or command (in the documented way) in a certain interface. Some others do the
same, but use all kinds of illegal parameters, and verify that the server stays
alive and rejects the requests with reasonable error codes. Some test suites
simulate an application (typically consisting of a few modules of an
application), some try to do tricky requests in general, and some test suites
even test internal functions with help of special Load Modules on target.

Another interesting category of test suites is the one checking that fixed bugs
do not reoccur. When a bugfix is introduced, a test case that checks for that
specific bug is written and submitted to the affected test suites.

Aim for finding bugs. Write whatever test that has the highest probability of
finding a bug, now or in the future. Concentrate more on the critical parts.
Bugs in critical subsystems are much more expensive than others.

Aim for functionality testing rather than implementation details. Implementation
details change quite often, and the test suites are to be long lived.
Implementation details often differ on different platforms and versions. If
implementation details must be tested, try to factor them out into separate test
cases. These test cases can later be rewritten or skipped.

Also, aim for testing everything once, no less, no more. It is not effective
having every test case fail only because one function in the interface changed.
