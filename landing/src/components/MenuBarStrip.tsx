"use client"

import { motion } from "motion/react"
import { Search } from "lucide-react"
import { AppleLogo } from "./primitives"

const MENUS = ["File", "Edit", "View", "Window", "Help"]

/**
 * A macOS menu bar, which is where DeskArt actually lives — the strip is a
 * literal depiction of the product surface, not decoration.
 */
export function MenuBarStrip() {
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.6, delay: 0.9, ease: "easeOut" }}
      className="relative z-10 h-10 border-t border-b border-white/10 bg-black/40 backdrop-blur-md"
    >
      <div className="mx-auto flex h-full max-w-6xl items-center justify-between px-6 text-xs">
        <div className="flex items-center gap-4">
          <AppleLogo className="h-3.5 w-3.5 text-white" />
          <span className="font-bold text-white">DeskArt</span>
          {MENUS.map((m, i) => (
            <span
              key={m}
              className={[
                "text-white/60",
                i > 2 ? "hidden sm:inline" : "",
                i > 3 ? "hidden md:inline" : "",
              ].join(" ")}
            >
              {m}
            </span>
          ))}
        </div>
        <div className="flex items-center gap-3 text-white/50">
          <Search className="h-3.5 w-3.5" />
          <span className="tabular-nums">Wed 1:09 PM</span>
        </div>
      </div>
    </motion.div>
  )
}
