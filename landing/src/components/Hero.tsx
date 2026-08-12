"use client"

import { motion } from "motion/react"
import { AppleButton, gradientStyle } from "./primitives"
import { DMG } from "@/lib/links"

const EASE = [0.22, 1, 0.36, 1] as const

export function Hero() {
  return (
    <section className="relative z-10 flex flex-col items-center px-6 pt-16 pb-20 text-center md:pt-28">
      <motion.h1
        initial={{ opacity: 0, y: 16 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.3, ease: EASE }}
        className="text-4xl leading-[0.9] font-semibold tracking-tight text-balance md:text-7xl"
      >
        <span className="block text-white">Your Desktop.</span>
        <span className="animate-shiny mt-1 block" style={gradientStyle}>
          Rearranged
        </span>
      </motion.h1>

      <motion.p
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, delay: 0.5, ease: EASE }}
        className="mt-8 max-w-md text-base leading-[1.5] text-pretty text-white/60"
      >
        DeskArt is a free macOS menu bar app that moves the icons already on your
        Desktop into text, hearts, spirals and twelve more shapes. Preview first,
        undo anything.
      </motion.p>

      <motion.div
        initial={{ opacity: 0, y: 12 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.7, delay: 0.7, ease: EASE }}
        className="mt-9 flex flex-col items-center gap-3"
      >
        <AppleButton href={DMG} />
        <p className="text-xs text-white/40">
          Free and open source · macOS 13+ · Apple silicon &amp; Intel
        </p>
      </motion.div>
    </section>
  )
}
