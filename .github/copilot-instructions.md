# Garmin Connect IQ Project Instructions

This repository is a Garmin Connect IQ watch application written in Monkey C.

## Before Changing Code

- Inspect `manifest.xml`, `monkey.jungle`, and the relevant files under `source/` and `resources/` before making changes.
- Treat the minimum API level and the products listed in `manifest.xml` as compatibility constraints.
- Check the installed Connect IQ SDK API documentation before using a module, class, method, annotation, or resource syntax. Do not invent Monkey C APIs.
- Preserve the app type and existing project structure unless the request explicitly changes them.

## Implementation Conventions

- Follow the naming, imports, indentation, and lifecycle patterns already present in neighboring `.mc` files.
- Keep application lifecycle logic in the `Application.AppBase` subclass and presentation/input behavior in views, delegates, and data fields as appropriate.
- Put user-visible text in `resources/strings/strings.xml`; reference it through generated `Rez` symbols instead of hard-coding it.
- Put layouts, drawables, fonts, settings, and properties in their corresponding resource directories. Account for different display sizes, shapes, color depths, and touch/button input.
- Prefer APIs available at the project's minimum SDK version. When a newer API is necessary, use Garmin-supported API-level checks or annotations and retain a compatible fallback.
- Avoid unnecessary allocations, background work, and frequent storage writes. Watch apps have strict memory, battery, and execution-time limits.
- Never commit developer signing keys, credentials, generated packages, or local SDK paths.

## Validation

- After source or resource changes, build with the Monkey C VS Code extension or `monkeyc` for at least one product declared in `manifest.xml`.
- Run the app in the Connect IQ simulator and exercise the changed lifecycle, rendering, and input paths.
- For compatibility-sensitive changes, build or simulate representative round, square, touch, and button-driven products that the manifest supports.
- Report the product and SDK used for validation, plus any checks that could not be run locally.

## Documentation Sources

Prefer Garmin's official documentation:

- Connect IQ documentation: https://developer.garmin.com/connect-iq/
- API reference: https://developer.garmin.com/connect-iq/api-docs/
- Device reference: https://developer.garmin.com/connect-iq/device-reference/
- UX guidelines: https://developer.garmin.com/connect-iq/user-experience-guidelines/
