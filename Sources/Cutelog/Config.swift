/*
    Copyright 2022 natinusala

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

/// Connection timeout.
let connectTimeout = 10 * 1000

/// Interval between connection steps and attempts.
let connectInterval = 0.5

/// Interval between every buffer batch dequeueing.
let workerInterval = 0.05

/// How many log messages to send in one buffer dequeue.
let batchSize = 100
