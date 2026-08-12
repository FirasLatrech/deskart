"use client"

import { motion } from "motion/react"
import { AppleButton, GhostButton, SectionEyebrow } from "./primitives"
import { DMG, RELEASES } from "@/lib/links"

const STEPS = [
  {
    strong: "Download the DMG",
    rest: " and drag DeskArt into your Applications folder.",
  },
  {
    strong: "Right-click DeskArt and choose Open",
    rest: ", then Open again. DeskArt isn't notarised by Apple, so a normal double-click is refused the first time. You only do this once.",
  },
  {
    strong: "Allow it to control Finder",
    rest: " when macOS asks. Finder is the only way to read and set Desktop icon positions — there is no public API for it.",
  },
  {
    strong: "Turn Desktop sorting off",
    rest: " — right-click the Desktop, Sort By, None. With sorting on, Finder immediately undoes any arrangement.",
  },
]

export function Install() {
  return (
    <section
      id="install"
      className="relative z-10 mx-auto max-w-6xl border-t border-white/10 px-6 py-20 md:py-28"
    >
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.7, ease: [0.22, 1, 0.36, 1] }}
      >
        <SectionEyebrow label="Install" tag="~1 minute" />
        <h2 className="mt-5 text-3xl leading-[1.02] font-semibold tracking-tight text-balance md:text-5xl">
          Four steps, once.
        </h2>

        <ol className="mt-10 grid max-w-2xl gap-3">
          {STEPS.map((s, i) => (
            <li
              key={s.strong}
              className="liquid-glass flex gap-4 rounded-xl px-5 py-4"
            >
              <span className="flex h-7 w-7 flex-none items-center justify-center rounded-full bg-white/10 text-[13px] font-semibold tabular-nums">
                {i + 1}
              </span>
              <p className="text-sm leading-[1.6] text-pretty text-white/60">
                <strong className="font-semibold text-white">{s.strong}</strong>
                {s.rest}
              </p>
            </li>
          ))}
        </ol>

        <div className="liquid-glass mt-6 max-w-2xl rounded-xl px-5 py-4">
          <p className="text-sm leading-[1.6] text-pretty text-white/60">
            <strong className="font-semibold text-white">
              If macOS says the app is damaged
            </strong>
            , clear the quarantine flag:
          </p>
          <code className="mt-2.5 block overflow-x-auto rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white/80">
            xattr -dr com.apple.quarantine /Applications/DeskArt.app
          </code>
        </div>

        <div className="mt-9 flex flex-wrap gap-3">
          <AppleButton href={DMG} />
          <GhostButton href={RELEASES}>All releases</GhostButton>
        </div>
      </motion.div>
    </section>
  )
}
