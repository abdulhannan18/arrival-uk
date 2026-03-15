"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const node_test_1 = __importDefault(require("node:test"));
const strict_1 = __importDefault(require("node:assert/strict"));
const privileged_1 = require("./privileged");
function makeContext(uid) {
    if (!uid)
        return {};
    return { auth: { uid } };
}
function makeDB(resolver) {
    return {
        collection(name) {
            return {
                doc(id) {
                    return {
                        async get() {
                            return resolver(`${name}/${id}`);
                        },
                    };
                },
            };
        },
    };
}
(0, node_test_1.default)("isPrivilegedCaller rejects unauthenticated calls", async () => {
    const db = makeDB(() => ({ exists: true }));
    const result = await (0, privileged_1.isPrivilegedCaller)(makeContext(), db);
    strict_1.default.equal(result, false);
});
(0, node_test_1.default)("isPrivilegedCaller returns true when admin doc exists", async () => {
    const userId = "admin-user";
    (0, privileged_1.invalidatePrivilegedCallerCache)(userId);
    const db = makeDB((path) => ({ exists: path === `admins/${userId}` }));
    const result = await (0, privileged_1.isPrivilegedCaller)(makeContext(userId), db);
    strict_1.default.equal(result, true);
    (0, privileged_1.invalidatePrivilegedCallerCache)(userId);
});
(0, node_test_1.default)("isPrivilegedCaller caches lookup results", async () => {
    const userId = "cached-user";
    (0, privileged_1.invalidatePrivilegedCallerCache)(userId);
    let reads = 0;
    const db = makeDB(() => {
        reads += 1;
        return { exists: true };
    });
    const first = await (0, privileged_1.isPrivilegedCaller)(makeContext(userId), db);
    const second = await (0, privileged_1.isPrivilegedCaller)(makeContext(userId), db);
    strict_1.default.equal(first, true);
    strict_1.default.equal(second, true);
    strict_1.default.equal(reads, 1);
    (0, privileged_1.invalidatePrivilegedCallerCache)(userId);
});
//# sourceMappingURL=privileged.test.js.map