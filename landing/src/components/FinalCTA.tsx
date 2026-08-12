"use client"

import { motion } from "motion/react"
import { AppleButton, GhostButton } from "./primitives"
import { DMG, REPO } from "@/lib/links"

export function FinalCTA() {
  return (
    <section className="relative z-10 mx-auto max-w-6xl px-6 py-20 md:py-32">
      <motion.div
        initial={{ opacity: 0, y: 24 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true, amount: 0.3 }}
        transition={{ duration: 0.8, ease: [0.22, 1, 0.36, 1] }}
        className="liquid-glass relative overflow-hidden rounded-3xl px-8 py-16 text-center md:py-24"
      >
        <div
          aria-hidden="true"
          className="pointer-events-none absolute inset-0 opacity-30"
          style={{
            background:
              "radial-gradient(600px circle at 50% 0%, rgba(255,255,255,0.15), transparent 70%)",
          }}
        />
        <div className="relative">
          <h2 className="text-4xl leading-[1.02] font-semibold tracking-tight text-balance md:text-6xl">
            Clear the grid.
            <br />
            Make something.
          </h2>
          <p className="mx-auto mt-6 max-w-md text-sm leading-[1.6] text-pretty text-white/60">
            Free, open source, and entirely undoable. Your Desktop goes back
            exactly as it was whenever you want it to.
          </p>
          <div className="mt-9 flex flex-wrap justify-center gap-3">
            <AppleButton href={DMG} />
            <GhostButton href={REPO}>View source</GhostButton>
          </div>
        </div>
      </motion.div>
    </section>
  )
}
