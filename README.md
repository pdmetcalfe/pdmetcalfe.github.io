# pdmetcalfe.github.io

Source for [Paul Metcalfe's personal website and blog](https://pdmetcalfe.github.io), built from [Typst](https://typst.app) documents with [Calepin](https://vincentarelbundock.github.io/calepin).

## Structure

- `*.typ` — top-level pages (home, about, blog index, 404, notes)
- `posts/YYYY/*.typ` — blog posts, grouped by year
- `assets/` — static files (images, etc.)
- `calepin.toml` — site configuration (theme, menus, sidebar, footer)

## Building locally

Requires [Typst](https://typst.app) and [Calepin](https://vincentarelbundock.github.io/calepin) installed.

```sh
calepin compile --format html . ./_site
```

Or preview with live reload:

```sh
calepin watch .
```

## Deployment

Pushes to `main` trigger [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml), which builds the site with Calepin and deploys it to GitHub Pages.
