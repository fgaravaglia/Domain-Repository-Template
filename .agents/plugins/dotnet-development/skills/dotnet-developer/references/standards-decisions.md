# Standards Decisions Log

If the owner overrules an entry, update the affected reference file and this log together.

| # | Issue in the source docs | Decision in this skill | Why |
| --- | --- | --- | --- |
| 1 | Coding doc says "use primary constructor syntax for DI" **and** "constructor DI with `ArgumentNullException` checks" **and** "private fields in `#region Fields`". Primary constructors cannot satisfy the last two. | Classic constructors for services with injected dependencies. Primary constructors only for records/DTOs/trivial types. | Two rules out of three require explicit fields and guards; primary-constructor parameters are also mutable captures. |
| 2 | Coding doc: "Do not emit Arrange/Act/Assert comments". NUnit doc: "Write all tests using AAA" with banner comments. | Test code uses the AAA banner comments (NUnit doc). Production code has none. | The NUnit doc is the specific rule for tests; the coding-doc line reads as a generic guard against noisy comments. **Owner to confirm.** |
| 3 | NUnit doc samples use Moq syntax (`Setup`, `It.IsAny`, `ReturnsAsync`) while Moq is FORBIDDEN and NSubstitute is the standard. | Samples rewritten with NSubstitute (`Returns`, `Arg.Any`, `Received`). | Samples must not contradict the rules they illustrate. |
| 4 | NUnit samples end with `Assert.Pass()`. | Removed; documented as an anti-pattern. | A test passes when nothing fails; `Assert.Pass()` throws internally and skips the code after it. |
| 5 | NUnit doc recommends `Assert.AreEqual`, `CollectionAssert`, `StringAssert`. | Constraint model (`Assert.That`) only for new code. Classic asserts are legacy. | In NUnit 4 they moved to `NUnit.Framework.Legacy` / `ClassicAssert`; the constraint model is the documented primary style. |
| 6 | NUnit sample asserts `Is.Not.Null.Or.Empty` on a string. | Replaced with `Is.EqualTo(token)`. | `Not.Null.Or.Empty` accepts the empty string, so it is a weak assertion and redundant next to the equality check. |
| 7 | NUnit samples: `Id = new Guid()` (all zeros) and `async Task` test with no `await` (CS1998). | `Guid.NewGuid()`; sync test method when using `Assert.ThrowsAsync` without await. | Avoid sample-induced bugs and warnings (warnings are errors in this setup). |
| 8 | Coding doc: "latest C#, currently C# 13" and ".NET 8 or higher". | `net10.0` LTS with the SDK-default C# (14). .NET 8/9 only for existing code. | .NET 10 LTS shipped Nov 2025; .NET 8 and 9 reach end of support on 10 Nov 2026 (per Microsoft's lifecycle announcement). |
| 9 | Coding doc: "Use `ConfigureAwait(false)` where appropriate". | Libraries: yes. ASP.NET Core application code: no. | No synchronization context in ASP.NET Core; adds noise. |
| 10 | Coding doc: "Return Task or Task from async methods" (typo). | `Task` or `Task<T>`; `ValueTask` only when measured. | Clarification. |
| 11 | Coding doc "Security" section contains "Use C# 13+ features and .NET 8 optimizations" and "secure coding for AI/ML operations". | Moved the language/runtime line to platform setup; AI/ML line dropped from the general rules. **Owner to confirm** if AI/ML-specific rules are wanted (prompt injection, model I/O validation, data leakage). | Not security guidance for the typical API; looks misfiled. |
| 12 | Doc standards: explicit `<DocumentationFile>` path in csproj. | `GenerateDocumentationFile` only. | The explicit path is redundant unless a custom location is needed. |
| 13 | Doc standards example returns `null` "if the criteria is invalid". | Throw (or explicit result) instead. | Silent nulls move the failure away from the cause. |
| 14 | Many bullets are written as tutor instructions ("Guide users...", "Demonstrate...", "Explain..."). | Treated as teach mode, applied only when the user asks to learn. Default mode produces compliant code. | Otherwise every code request would turn into a lecture. |
| 15 | Container command `dotnet publish --os linux --arch x64 -p:PublishProfile=DefaultContainer`. | Kept, with a note to check the SDK version docs. | Container tooling changed across SDK releases; verify against the SDK in use. |
| 16 | Moq and FluentAssertions are forbidden but the reason is not documented. | Rule kept as written. The likely reason is licensing / supply-chain risk (both libraries had trust/licensing controversies); ask the owner to document it. | A rule without a reason erodes; one line in the doc fixes that. |

## Open questions for the standards owner

1. Confirm #2 (AAA banners in tests) and #11 (AI/ML guidance).
2. Should FluentValidation, MediatR-style mediators or AutoMapper-style mappers be explicitly allowed or forbidden? (The skill is neutral; mediator licensing should be checked before adoption.)
3. Which API style is standard: minimal APIs or controllers?
4. Is a repository abstraction mandatory per aggregate, or only where it adds value?
5. Does the organization mandate an SBOM / dependency register that CI should produce?
