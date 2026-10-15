# Lifecycle diagnostics timing and metadata

Diagnostics use independent initialize/update_user collectors. Context, key,
step, action, error name and evaluation-source values serialize through explicit
central wire mappings. `metadata.markers` is a JSON string. Optional unavailable
fields are omitted rather than fabricated.

Network markers cover the actual HTTP request and response decoding performed by
the network service. Each real attempt has one start/end pair; malformed response
decoding records a failed end while retaining known HTTP status/region. A terminal
timeout closes active work once. A timeout during backoff retains the already-ended
HTTP attempt and reports a separate overall timeout error. In-flight HTTP may
finish after the caller; its late result is discarded and cannot start retries.

Process covers local response validation and memory application. InternalStore.save
updates memory before awaiting its asynchronous disk write; the caller deliberately
does not await save, preserving the existing SDK completion behavior. Process and
overall ends therefore do not promise persistence durability. Tests/callers that
depend on a warm disk cache must establish persistence explicitly first. No
synthetic disk-persistence marker is emitted.

Overall evaluationDetails is an immutable snapshot of the operation's resulting
source, LCUT and received-at time. NetworkNotModified and Cache retain the store's
actual times; NoValues/Uninitialized omit times. This diagnostics schema is separate
from public per-config evaluation metadata and does not change that API's flags.
Rejected SDK-key responses retain raw response sampling but report an application
error and failed processing/overall result. Superseded updates retain deliberate
event suppression and generation-based store protection.

Sampling is unchanged: a positive integer response diagnostics/context rate N
selects with probability1/N; missing/zero rates and null failure responses do not
sample. Force sampling bypasses this policy for deterministic acceptance tests.
Errors have typed names, messages and optional actual codes. HTTP failures use
their known status; HTTP client errors use the library's message without its
separate request URI. Response bodies, SDK keys and mismatched key hashes are not
copied into diagnostic error metadata. Region is emitted only when returned by
the server. Platform connectivity, bootstrap and polling are outside this scope.
