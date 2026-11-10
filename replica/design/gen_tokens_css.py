#!/usr/bin/env python3
"""Generate tokens.css from tokens.json. Standard library only.

    python3 gen_tokens_css.py            # writes tokens.css next to this file

Run it after every change to tokens.json (and run contrast.py first).
"""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))

FILLS = {
    "light": {"card": "rgba(255,255,255,.85)", "sunken": "rgba(255,255,255,.55)",
              "glass": "rgba(255,255,255,.28)", "edge": "rgba(255,255,255,.65)"},
    "dark": {"card": "rgba(34,38,58,.80)", "sunken": "rgba(18,21,30,.70)",
             "glass": "rgba(40,46,70,.35)", "edge": "rgba(255,255,255,.18)"},
}


def theme_vars(tokens, name, indent="  "):
    colors = tokens["color"][name]
    shadow = tokens["shadow"]["card" if name == "light" else "card-dark"]
    f = FILLS[name]
    lines = ["--color-%s: %s;" % (k, v) for k, v in colors.items() if not k.startswith("_")]
    lines += [
        "--shadow-card: %s;" % shadow,
        "--card-fill: %s;" % f["card"],
        "--sunken-fill: %s;" % f["sunken"],
        "--glass-fill: %s;" % f["glass"],
        "--glass-edge: %s;" % f["edge"],
        # re-declared per theme: a var() inside a custom property resolves where it is declared
        "--sky: linear-gradient(180deg, var(--color-sky-top) 0%, var(--color-sky-mid) 45%, var(--color-bg) 78%);",
    ]
    return "\n".join(indent + line for line in lines)


def main():
    with open(os.path.join(HERE, "tokens.json"), encoding="utf-8") as fh:
        t = json.load(fh)
    space = "\n".join("  --space-%d: %dpx;" % (i, v) for i, v in enumerate(t["space"]))
    radius = "\n".join("  --radius-%s: %spx;" % (k, v)
                       for k, v in t["radius"].items() if not k.startswith("_"))
    css = """/* Generated from tokens.json by gen_tokens_css.py. Do not edit by hand.
   Used by the design preview now and by the landing page in /replica-launch.
   Themes: follows the system; data-theme="light" or "dark" on any element forces one. */
:root {
%(light)s
  --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Text", Inter, system-ui, sans-serif;
  --font-rounded: ui-rounded, "SF Pro Rounded", -apple-system, system-ui, sans-serif;
%(space)s
%(radius)s
  --ease-smooth: cubic-bezier(.32,.72,0,1);
  --dur-tap: 250ms;
  --dur-default: 350ms;
  color-scheme: light dark;
}
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) {
%(dark_nested)s
  }
}
:root[data-theme="dark"],
[data-theme="dark"] {
%(dark)s
}
[data-theme="light"] {
%(light)s
}
@media (prefers-reduced-motion: reduce) {
  :root { --dur-tap: 0ms; --dur-default: 200ms; }
}
@media (prefers-reduced-transparency: reduce) {
  :root {
    --card-fill: var(--color-surface);
    --sunken-fill: var(--color-surface-sunken);
    --glass-fill: var(--color-surface-raised);
  }
}
""" % {
        "light": theme_vars(t, "light"),
        "dark": theme_vars(t, "dark"),
        "dark_nested": theme_vars(t, "dark", "    "),
        "space": space,
        "radius": radius,
    }
    with open(os.path.join(HERE, "tokens.css"), "w", encoding="utf-8") as fh:
        fh.write(css)
    print("tokens.css written")


if __name__ == "__main__":
    main()
