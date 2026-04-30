# Further Research Questions

**Role:** Researcher
**Phase:** Post-decision facilitation — architecture review
**Status:** RQ-F1 Complete
**Purpose:** These questions emerged during the developer's review of `documentation/project/architecture.md`. They are not blockers on any current decision but should be investigated before implementation begins or before the relevant Senior Developer plans are written.

Each question includes the context that motivated it and what a useful answer looks like.

---

## RQ-F1 — Python ORM and migration landscape

**Motivated by:** Developer question during architecture review (Point 1).
**Context:** The current stack specifies SQLAlchemy 2.x async + Alembic (ADR-004). The developer comes from a Node.js background and is familiar with knex.js — a query builder that also handles migrations, not a full ORM. The question is whether the Python landscape offers anything comparable, and whether SQLModel is a worthwhile addition.

**Specific questions to answer:**

1. Is there a Python equivalent to knex.js (a single library handling both query building and migrations)? If so, how mature and widely adopted is it?
2. What is the current state of **SQLModel** (the FastAPI author's library combining SQLAlchemy ORM + Pydantic)?
   - Is its Pydantic v2 support stable and production-ready as of early 2026?
   - Does it meaningfully reduce boilerplate in a project that already uses Pydantic v2 throughout (i.e. would a single SQLModel class replace a separate ORM model + Pydantic schema)?
   - What are the known limitations or rough edges when using SQLModel with async SQLAlchemy and Alembic?
   - Is it widely used in production FastAPI projects?
3. Is SQLAlchemy 2.x async + Alembic the de facto standard pairing for async Python + PostgreSQL in 2025/2026, or has anything displaced it?

**What a useful answer looks like:** A clear recommendation on whether to add SQLModel to the stack (with rationale), and confirmation or correction of the current ADR-004 choice. If SQLModel is recommended, note any migration-generation caveats specific to async SQLAlchemy.

### Findings

#### 1. Python equivalent to knex.js

There is **no direct single-library equivalent** to knex.js in the Python ecosystem. Python's culture historically separates query building and migrations into distinct libraries. The landscape breaks down as follows:

- **SQLAlchemy + Alembic** — the de facto standard. SQLAlchemy Core is a powerful query builder (closer in spirit to knex than the ORM layer is), and Alembic is its companion migration tool authored by the same maintainer (Mike Bayer). They are separate installs but are designed to work together and Alembic introspects SQLAlchemy metadata to autogenerate migrations. This is the closest "pairing" to knex's experience, but it is two packages, not one.
- **Piccolo ORM** — the nearest single-library equivalent. Piccolo is an async-first ORM and query builder with built-in migrations (including autogeneration), an admin UI, and `asyncpg` support. It is actively maintained (v1.x, regular releases through 2025). However, it is **niche** compared to SQLAlchemy — small community, limited third-party integrations, and far less production use in FastAPI projects. Adopting it would trade ecosystem depth for ergonomic simplicity.
- **Tortoise ORM** — another async ORM with built-in migrations (Aerich). Django-inspired API. Smaller community than SQLAlchemy; mixed reports on migration robustness.
- **PyPika** — pure query builder, no migrations. Not a fit.
- **Peewee** — mature, simple ORM with a migration extension, but sync-first; async story is immature.

**Conclusion:** A knex-style single-library experience exists (Piccolo, Tortoise) but at significant cost in ecosystem maturity. For a production self-hosted app using FastAPI + PostgreSQL, SQLAlchemy + Alembic remains the pragmatic choice even though it is two packages.

#### 2. State of SQLModel (early 2026)

**Pydantic v2 support:** Stable and production-ready. Pydantic v2 support landed in SQLModel 0.0.14 (December 2023) and has been iterated on through 2024–2025 (including type refactors for Pydantic 2.7 and alias fixes). As of early 2026, SQLModel is on actively released 0.0.x versions with FastAPI-tracking dependency bumps. Pydantic v1 is no longer a concern for new projects.

**Caveat on version numbering:** SQLModel is still on 0.0.x releases — it has never hit 1.0. The API is considered usable in production (tiangolo uses it himself and recommends it in the official FastAPI tutorial), but the version number reflects that breaking changes remain possible.

**Boilerplate reduction:** Yes, meaningfully — but with trade-offs. A single `SQLModel` class with `table=True` can serve as the ORM model, and companion classes (without `table=True`) serve as the Pydantic request/response schemas. In practice most projects still define 3–4 classes per entity (`Base`, `Create`, `Read`, `Update`, `Table`) because mixing validation rules, ORM field configuration, and API shape into one class gets unwieldy. The saving vs. "pure SQLAlchemy 2.x ORM + separate Pydantic schemas" is real but modest — probably 20–30% fewer lines for simple entities, less for complex ones.

**Known limitations / rough edges:**

- **Advanced SQLAlchemy features require dropping down to raw SQLAlchemy.** Complex relationships, hybrid properties, custom types, and advanced query patterns often need `sqlalchemy.orm` imports anyway. You end up with a mixed codebase.
- **Async relationships are awkward.** Lazy loading is not available in async SQLAlchemy, so you must use `selectinload` / `joinedload` explicitly — SQLModel does not hide this, and its relationship helpers are less mature than SQLAlchemy's.
- **Alembic autogenerate works but requires care.** Forgetting to import SQLModel modules before Alembic accesses `SQLModel.metadata` silently produces empty migrations. You also need the standard async bridging pattern (`async_engine_from_config` + `connection.run_sync`) in `env.py` — this is a general async-SQLAlchemy + Alembic issue, not SQLModel-specific, but it catches SQLModel users more often because tutorials often skip it.
- **Enum handling in autogenerated migrations is imperfect** — PostgreSQL enum ALTER operations often need manual migration edits. Again a general Alembic limitation, not SQLModel-specific.
- **Type-checker friction.** Some mypy/pyright configurations complain about SQLModel's dual-nature classes (Pydantic model + SQLAlchemy mapped class). Usually resolvable, sometimes noisy.

**Production adoption:** Moderate and growing, but **not dominant**. SQLModel is promoted heavily in the FastAPI docs and tutorials, and there are well-known template repos (`testdrivenio/fastapi-sqlmodel-alembic`, `jonra1993/fastapi-alembic-sqlmodel-async`). However, serious production FastAPI codebases often still use vanilla SQLAlchemy 2.x + Pydantic v2 separately, particularly where teams have prior SQLAlchemy experience or need advanced ORM features. There is no signal that SQLModel has displaced SQLAlchemy as the default choice in production — it is a popular option, not the consensus one.

#### 3. Is SQLAlchemy 2.x async + Alembic still the de facto standard?

**Yes, unambiguously, as of early 2026.** SQLAlchemy 2.0 (released March 2023) introduced a unified sync/async API and modern typed ORM syntax that has become the reference for Python database access. `asyncpg` is the universally recommended async PostgreSQL driver. Alembic remains the only broadly adopted migration tool for SQLAlchemy and has no serious competitor in that space. Nothing has displaced this pairing — the debate is only whether to add SQLModel as a convenience layer on top, not whether to replace SQLAlchemy itself.

### Recommendation

**Do not add SQLModel to the stack. Keep ADR-004 as-is: SQLAlchemy 2.x async (`asyncpg`) + Alembic, with Pydantic v2 schemas defined separately.**

Rationale:

1. **SQLModel's benefit is modest in this project.** The savings come from unifying ORM model and API schema classes, but most real entities benefit from separate `Create`/`Read`/`Update`/`Table` shapes anyway. The boilerplate reduction does not justify adding a 0.0.x dependency to the critical path.
2. **SQLModel leaks abstraction.** For anything beyond trivial queries, you end up importing from `sqlalchemy.orm` regardless, producing a mixed codebase that is harder to reason about than either pure SQLAlchemy 2.x or pure SQLModel.
3. **Async + relationships are where SQLModel is weakest**, and this project is async-first with a non-trivial relational model (Workspaces → Personas → Conversations → Messages, plus Mentor memory layers). SQLAlchemy 2.x's typed `Mapped[...]` syntax is well-documented and battle-tested for exactly this pattern.
4. **Version stability.** SQLModel is still on 0.0.x after four years. For a self-hosted app intended to last, depending directly on SQLAlchemy 2.x (a mature 2.0 release) is lower risk.
5. **Developer background.** Coming from knex.js, SQLAlchemy 2.x Core (the expression language) will feel more familiar than the ORM layer — the developer can lean on Core for complex queries and use the ORM only where it adds clarity. SQLModel would obscure this distinction.

**On the knex.js analogy:** There is no true single-library equivalent in Python that is worth adopting for this project. The two-library SQLAlchemy + Alembic pairing is the mature answer; treat them as a bundle. Piccolo is interesting but too niche for a production stack.

**Migration caveats to carry forward into implementation (apply regardless of SQLModel decision):**

- In `alembic/env.py`, use `async_engine_from_config` and `connection.run_sync(context.run_migrations)` — the default generated `env.py` is sync-only and will fail with `asyncpg`.
- Ensure all model modules are imported before Alembic reads `Base.metadata`, otherwise autogenerate silently produces empty migrations.
- Review every autogenerated migration by hand, especially for PostgreSQL enum changes — Alembic does not handle `ALTER TYPE` well.
- Watch for ConfigParser `%` interpolation errors in `alembic.ini` when DB URLs contain `%` characters (e.g. URL-encoded passwords); escape as `%%` or load the URL in `env.py` from the environment.

**Confirmation:** ADR-004's choice of SQLAlchemy 2.x async + Alembic + `asyncpg` is correct and aligned with the 2025/2026 Python consensus for async FastAPI + PostgreSQL. No change needed.

### Sources

- [SQLModel official site (tiangolo)](https://sqlmodel.tiangolo.com/)
- [SQLModel release notes](https://sqlmodel.tiangolo.com/release-notes/)
- [SQLModel Pydantic v2 discussion #621](https://github.com/fastapi/sqlmodel/discussions/621)
- [SQLModel 0.0.14 Pydantic v2 announcement (tiangolo on X)](https://x.com/tiangolo/status/1731690474019147819)
- [Alembic async migration discussion #1208](https://github.com/sqlalchemy/alembic/discussions/1208)
- [Alembic supporting async migrations discussion #1229](https://github.com/sqlalchemy/alembic/discussions/1229)
- [TestDriven.io: FastAPI with Async SQLAlchemy, SQLModel, and Alembic](https://testdriven.io/blog/fastapi-sqlmodel/)
- [jonra1993/fastapi-alembic-sqlmodel-async template](https://github.com/jonra1993/fastapi-alembic-sqlmodel-async)
- [testdrivenio/fastapi-sqlmodel-alembic template](https://github.com/testdrivenio/fastapi-sqlmodel-alembic)
- [Piccolo ORM (GitHub)](https://github.com/piccolo-orm/piccolo)
- [Piccolo ORM official site](https://piccolo-orm.com/)
- [PyPika documentation](https://pypika.readthedocs.io/en/latest/)
- [FastAPI SQL Databases tutorial (uses SQLModel)](https://fastapi.tiangolo.com/tutorial/sql-databases/)
