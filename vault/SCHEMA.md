# Schema — Notes Vault

## Directory Layout

```
raw/
  Daily/            YYYY-MM-DD.md — one file per day
  Topics/           Reference topics (used as [[Topics/name]] links)
  Notes/            Archived individual notes
  People/           People profiles
  Projects/         Project documentation
  Meetings/         Meeting notes
  BusinessIdeas/    Business ideas
  any/              Any additional categories
wiki/
  index.md          Catalog of all wiki pages
  log.md            Append-only chronological record
  overview.md       Living synthesis across all sources
  sources/          One summary page per source document
  entities/         People, companies, projects, products
  concepts/         Ideas, frameworks, methods, theories
  syntheses/        Saved query answers
```

## Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | Page type: daily, topic, person, project, meeting, note, source, entity, concept, synthesis |
| `tags` | No | Comma-separated labels for classification |
| `status` | No | `draft`, `active`, `archived` |
| `sources` | No | List of source slugs that inform this page (wiki only) |
| `last_updated` | Yes | Date of last update: YYYY-MM-DD |

## Naming Conventions

- Daily files: `YYYY-MM-DD.md`
- Topic files: `Kebab-Case.md` matching the topic name
- Entity files: `TitleCase.md` matching the entity name
- Concept files: `TitleCase.md` matching the concept name
- Source files: `kebab-case-slug.md`

## Wiki Links

Use `[[PageName]]` or `[[Category/PageName]]` to link pages.
KiwiFS resolves links with fuzzy matching.
