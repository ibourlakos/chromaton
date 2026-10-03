# Linux compatibility audit — 3 October 2026

Chromaton is runnable on this Linux x86_64 machine, both from its source
project and as a native exported build. All changes, downloaded binaries,
export templates, generated caches, test saves and build outputs were made
inside `chromaton-main`. No system package installation or system settings
changes were needed.

## Run

From this folder, use `./make play` for the source project or
`./make play-export` for the native build. `./make editor` opens the portable
editor. See TESTING.md for the complete command list.

The native build is `builds/linux/Chromaton.x86_64`, with its data in
`builds/linux/Chromaton.pck`. Keep both files together. Use the project
launcher to keep playing saves inside this folder.

## Findings and changes

| Check | Finding and action |
|---|---|
| Godot version | `project.godot` declares Godot 4.7, config format 5. Tested using the standard Linux Godot 4.7.2 build (`4.7.2.stable.official.ed1daf0bf`). No .NET SDK is needed. |
| Windows paths | Game resources use forward-slash `res://` paths; progress uses `user://`. Windows paths were confined to the Windows task runner and its documentation. Added the executable Bash `make` launcher. |
| Case-sensitive filenames | All 97 quoted resource references resolve with exact case. All 21 campaign level IDs match their JSON filenames. No case-colliding original filenames were found. |
| Native libraries | No project DLLs, shared objects, GDExtensions, GDNative libraries or C# assemblies. The portable engine and exported executable resolve all their linked Linux libraries. |
| Plugins | No addons, enabled editor plugins or autoload plugins. Nothing requires conversion or removal. |
| Project settings | Main scene resolves to `main.tscn`; its script resolves correctly. The existing Compatibility renderer and 1280 × 800 canvas are suitable. The Godot version marker and gameplay settings were retained. |
| Imports | Rebuilt the missing `.godot/` cache from the included fonts and scripts. Imported assets are generated locally; source fonts and their licenses are included. |
| Rendering at runtime | The initial GLX OpenGL context failed; Godot fell back to Mesa software rendering. The Linux launcher explicitly uses OpenGL ES with software rendering, which starts cleanly. This affects only the launched process. `CHROMATON_SOFTWARE_RENDERING=0 ./make play` tries hardware acceleration. |
| Export settings | There was no export preset. Added a runnable Linux x86_64 preset, explicitly including `levels/*.json` and font licenses, while excluding development tools, tests and documentation. Downloaded matching export templates into the portable editor's project-local data folder and produced a release executable plus PCK. |
| Save locations | The Linux launcher redirects XDG data/config/cache/state and temporary/graphics caches into `.linux-user/`. Normal progress uses `.linux-user/data/`; tests and screenshots use `.linux-user/test-data/`. |
| Screenshot saves | Existing screenshot mode can emit progress-save signals despite using a throwaway progress object. The launcher isolates screenshot saves from normal playing data, including screenshot arguments passed to `play-export`. The audit's initial reference save was preserved under `.linux-user/validation/`, and normal playing progress starts fresh. |
| Runtime errors | Compilation, existing tests, clean source startup and native graphical checks pass. No GDScript gameplay changes were necessary. |

## Validation

- Headless import completed successfully; every GDScript compiled.
- All five existing test suites passed: inventions (34 checks), levels
  (643), simulation (92), workbench (432), and all paint-algebra checks.
- Headless game startup completed without script errors.
- Source screenshots verified the level menu, pattern book and completed
  puzzles, including `wash_out` and `either_not_both`.
- Both the PCK export and native Linux release export succeeded. Export logs
  confirm that the campaign index, all level JSON files, compiled game
  scripts, fonts and font licenses are packed.
- The native executable rendered the level menu, pattern book and all 21
  campaign levels through their reference completion paths without errors.
- Save isolation was checked using the launcher: validation writes its
  progress to the test profile, leaving normal playing progress fresh.

Evidence is under `.linux-user/validation/`; screenshots are under
`.linux-user/screenshots/`. The initial graphics failure log is retained
alongside the subsequent successful runs. Automated workbench tests cover
game interactions; graphical validation used screenshot mode rather than a
manual mouse-driven playthrough. Hardware rendering is not verified on this
machine; the tested launch path uses CPU rendering.

## Files added or updated

- `make`: Linux launcher, compile/test/screenshot/design/export tasks,
  project-local data directories, and the tested renderer configuration.
- `export_presets.cfg`: Linux release preset.
- `TESTING.md` and `CLAUDE.md`: Linux run and development instructions.
- `.gitignore`: ignores portable tooling, local data and builds.
- `LINUX_COMPATIBILITY.md`: this report.
- Generated `.godot/` imports, `.linux-tools/` engine/templates,
  `.linux-user/` validation data and `builds/linux/` release output.

## Download provenance

Portable engine and templates came from the
[official Godot 4.7.2 release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable).
Both download archives were checked against their GitHub release SHA-256
digests before extraction. Only Linux x86_64 debug/release templates and
their version file were retained from the template archive; downloaded
archives were removed afterward.

- Engine archive SHA-256:
  `cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4`
- Template archive SHA-256:
  `f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011`

Godot's documentation describes
[XDG overrides and portable editor mode](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)
and the need to
[include non-resource files when exporting](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html).
