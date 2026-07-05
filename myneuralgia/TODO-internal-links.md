# TODO: Internal Links — Fix 404s

After all articles are translated, internal links between articles lead to 404 pages.

## Example:
- https://myneuralgia-en.pages.dev/066-low-dose-naltrexone-patient-experiences
  - Internal links on this page point to non-existent URLs (404)

## Action needed:
- Review all translated articles for internal links
- Verify that linked slugs match actual filenames in `content/en/`
- Update or regenerate internal links after all translations are complete
- Re-build and re-deploy after fixes

## Notes:
- This likely affects multiple articles, not just 066
- The build script may generate links based on Polish slugs or numbering that doesn't match English filenames
- Check `build-en.ps1` logic for how internal links are resolved
