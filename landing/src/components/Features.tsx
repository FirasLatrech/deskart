"use client"

import { motion } from "motion/react"
import { SectionEyebrow } from "./primitives"

const CHIPS = [
  "Preview before applying",
  "Undo any arrangement",
  "Per-display layouts",
  "Verified writes",
]

/**
 * Each row states something the app genuinely does, with the number it
 * actually enforces — the 68pt floor and the snapshot-then-verify sequence
 * are real behaviour, not marketing rounding.
 */
const ROWS = [
  {
    title: "Snapshot",
    dot: "#ffffff",
    items: ["Every layout saved before it changes", "One click restores it exactly"],
  },
  {
    title: "Fit",
    dot: "#e5e5e5",
    items: ["68pt minimum between icons", "Count drops before spacing does"],
  },
  {
    title: "Place",
    dot: "#a3a3a3",
    items: ["Mapped to one display's bounds", "Leftovers parked in a corner block"],
  },
  {
    title: "Verify",
    dot: "#525252",
    items: ["Positions read back from Finder", "Mismatches reported, never hidden"],
  },
]

export function Features() {
  return (
    <section id="how" className="relative z-10 mx-auto max-w-6xl px-6 py-20 md:py-28">
      <div className="grid items-start gap-10 md:grid-cols-2 md:gap-16">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.4 }}
          transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
        >
          <SectionEyebrow label="How it works" tag="Reversible" />
          <h2 className="mt-5 text-3xl leading-[1.02] font-semibold tracking-tight text-balance md:text-5xl">
            Rearrange everything.
            <br />
            Put it all back.
          </h2>
          <p className="mt-6 max-w-md text-base leading-[1.6] text-pretty text-white/60">
            Moving every icon on your Desktop is the kind of thing you want to be
            able to take back. DeskArt snapshots your layout first, checks its own
            work afterwards, and never squeezes icons closer than they can legibly
            sit.
          </p>
          <div className="mt-7 flex flex-wrap gap-2">
            {CHIPS.map((c) => (
              <span
                key={c}
                className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1.5 text-xs text-white/70"
              >
                {c}
              </span>
            ))}
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true, amount: 0.3 }}
          transition={{ duration: 0.7, delay: 0.1, ease: [0.22, 1, 0.36, 1] }}
          className="liquid-glass rounded-2xl p-5"
        >
          <p className="text-xs text-white/50">
            Every apply · snapshot → fit → place → verify
          </p>
          <div className="mt-4 space-y-3">
            {ROWS.map((r) => (
              <div key={r.title} className="liquid-glass rounded-lg p-3">
                <div className="flex items-center gap-2.5">
                  <span
                    className="h-2 w-2 rounded-full"
                    style={{ background: r.dot }}
                  />
                  <span className="text-sm font-medium">{r.title}</span>
                </div>
                <ul className="mt-2 space-y-1 pl-[18px]">
                  {r.items.map((it) => (
                    <li key={it} className="text-xs leading-relaxed text-white/50">
                      {it}
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </motion.div>
      </div>
    </section>
  )
}
