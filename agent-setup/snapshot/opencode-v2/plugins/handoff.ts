import * as path from "node:path"
import * as fs from "node:fs/promises"

const HANDOFF_COMMAND = `GOAL: You are creating a handoff message to continue work in a new session.

<context>
When an AI assistant starts a fresh session, it spends significant time exploring the codebase—grepping, reading files, searching—before it can begin actual work. This "file archaeology" is wasteful when the previous session already discovered what matters.

A good handoff frontloads everything the next session needs so it can start implementing immediately.
</context>

<instructions>
Analyze this conversation and extract what matters for continuing the work.

1. Identify all relevant files that should be loaded into the next session's context

   Include files that will be edited, dependencies being touched, relevant tests, configs, and key reference docs. Be generous—the cost of an extra file is low; missing a critical one means another archaeology dig. Target 8-15 files, up to 20 for complex work.

2. Draft the context and goal description

   Describe what we're working on and provide whatever context helps continue the work. Structure it based on what fits the conversation—could be tasks, findings, a simple paragraph, or detailed steps.

   Preserve: decisions, constraints, user preferences, technical patterns.

   Exclude: conversation back-and-forth, dead ends, meta-commentary.

The user controls what context matters. If they mentioned something to preserve, include it—trust their judgment about their workflow.
</instructions>

<user_input>
This is what the next session should focus on. Use it to shape your handoff's direction—don't investigate or search, just incorporate the intent into your context and goals.

If empty, capture a natural continuation of the current conversation's direction.

USER: $ARGUMENTS
</user_input>

---

After generating the handoff message, IMMEDIATELY call handoff with your prompt and files:
\`handoff(prompt="...", files=["src/foo.ts", "src/bar.ts", ...])\``

const BINARY_EXTENSIONS = new Set([
  ".zip", ".tar", ".gz", ".exe", ".dll", ".so", ".class", ".jar", ".war",
  ".7z", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".odt", ".ods",
  ".odp", ".bin", ".dat", ".obj", ".o", ".a", ".lib", ".wasm", ".pyc", ".pyo"
])

async function isBinaryFile(filepath: string): Promise<boolean> {
  const ext = path.extname(filepath).toLowerCase()
  if (BINARY_EXTENSIONS.has(ext)) return true
  try {
    const buffer = await fs.readFile(filepath)
    if (!buffer || buffer.length === 0) return false
    const bytes = buffer.subarray(0, Math.min(4096, buffer.length))
    let nonPrintable = 0
    for (let i = 0; i < bytes.length; i++) {
      const b = bytes[i]
      if (b === 0) return true
      if (b < 9 || (b > 13 && b < 32)) nonPrintable++
    }
    return nonPrintable / bytes.length > 0.3
  } catch {
    return false
  }
}

function formatFileContent(content: string): string {
  const lines = content.split("\n")
  const limit = 2000
  const raw = lines.slice(0, limit).map((l) => (l.length > 2000 ? l.substring(0, 2000) + "..." : l))
  const formatted = raw.map((l, idx) => `${(idx + 1).toString().padStart(5, "0")}| ${l}`)
  let out = "<file>\n" + formatted.join("\n")
  if (lines.length > limit) {
    out += `\n\n(File has more lines. Use 'offset' parameter to read beyond line ${limit})`
  } else {
    out += `\n\n(End of file - total ${lines.length} lines)`
  }
  return out + "\n</file>"
}

function toolTitle(state: { content?: ReadonlyArray<{ type: string; text?: string }> }): string {
  const text = state.content?.find((c) => c.type === "text" && c.text)?.text
  if (!text) return ""
  const firstLine = text.split("\n")[0] ?? ""
  return firstLine.length > 100 ? firstLine.slice(0, 97) + "..." : firstLine
}

type V2Message = {
  type: string
  text?: string
  files?: ReadonlyArray<{ name?: string }>
  content?: ReadonlyArray<any>
}

function formatTranscript(messages: ReadonlyArray<V2Message>, limit?: number): string {
  const lines: string[] = []
  for (const msg of messages) {
    if (msg.type === "user") {
      lines.push("## User")
      if (msg.text) lines.push(msg.text)
      for (const file of msg.files ?? []) {
        lines.push(`[Attached: ${file.name || "file"}]`)
      }
      lines.push("")
    }
    if (msg.type === "assistant") {
      lines.push("## Assistant")
      for (const part of msg.content ?? []) {
        if (part.type === "text" && part.text) lines.push(part.text)
        if (part.type === "tool" && part.state?.status === "completed") {
          lines.push(`[Tool: ${part.name ?? "tool"}] ${toolTitle(part.state)}`)
        }
      }
      lines.push("")
    }
  }
  const output = lines.join("\n").trim()
  if (messages.length >= (limit ?? 100)) {
    return output + `\n\n(Showing ${messages.length} most recent messages. Use a higher 'limit' to see more.)`
  }
  return output + `\n\n(End of session - ${messages.length} messages)`
}

interface TuiApi {
  executeCommand(input: { body: { command: string } }): Promise<void>
  appendPrompt(input: { body: { text: string } }): Promise<void>
  showToast(input: {
    body: { title: string; message: string; variant: string; duration: number }
  }): Promise<void>
}

async function buildSyntheticFileParts(directory: string, refs: Set<string>): Promise<string[]> {
  const parts: string[] = []
  for (const ref of refs) {
    const filepath = path.resolve(directory, ref)
    try {
      const stats = await fs.stat(filepath)
      if (!stats.isFile()) continue
      if (await isBinaryFile(filepath)) continue
      const content = await fs.readFile(filepath, "utf-8")
      parts.push(`Called the Read tool with the following input: ${JSON.stringify({ filePath: filepath })}`)
      parts.push(formatFileContent(content))
    } catch {
      // skip unreadable
    }
  }
  return parts
}

export default {
  id: "opencode-handoff",
  async setup(ctx: any) {
    const processedSessions = new Set<string>()

    // 1. Register /handoff command
    if (ctx.command?.transform) {
      await ctx.command.transform((editor: any) => {
        editor.add({
          name: "handoff",
          description: "Create a focused handoff prompt for a new session",
          execute: async ({ sessionID, prompt, delivery }: any) => {
            const args = String(prompt?.text || "").trim()
            await ctx.session.prompt({
              sessionID,
              delivery,
              text: HANDOFF_COMMAND.replace(/\$ARGUMENTS/g, args),
            })
          },
        })
      })
    }

    // 2. Register handoff and read_session tools
    if (ctx.tool?.transform) {
      await ctx.tool.transform((editor: any) => {
        editor.add({
          name: "handoff",
          description: "Create a new session with the handoff prompt as an editable draft",
          input: {
            type: "object",
            properties: {
              prompt: { type: "string", description: "The generated handoff prompt" },
              files: {
                type: "array",
                items: { type: "string" },
                description: "Array of file paths to load into the new session's context",
              },
            },
            required: ["prompt"],
            additionalProperties: false,
          },
          async execute(input: any, context: { sessionID?: string }) {
            const args = input as { prompt: string; files?: string[] }
            const sessionReference = `Continuing work from session ${context?.sessionID || "unknown"}. When you lack specific information you can use read_session to get it.`
            const refs = new Set((args.files ?? []).map((f) => f.replace(/^@/, "")))
            const baseDir = ctx.location?.directory || process.cwd()
            const fileParts = refs.size ? await buildSyntheticFileParts(baseDir, refs) : []
            const fileContext = fileParts.length ? "\n\n" + fileParts.join("\n\n") : ""
            const fullPrompt = `${sessionReference}${fileContext}\n\n${args.prompt}`

            try {
              const tui = ctx.tui as TuiApi | undefined
              if (tui && typeof tui.executeCommand === "function") {
                await tui.executeCommand({ body: { command: "session_new" } })
                await new Promise((r) => setTimeout(r, 150))
                await tui.appendPrompt({ body: { text: fullPrompt } })
                if (typeof tui.showToast === "function") {
                  await tui.showToast({
                    body: {
                      title: "Handoff Ready",
                      message: "Review and edit the draft, then send",
                      variant: "success",
                      duration: 4000,
                    },
                  })
                }
                return { content: "Handoff prompt created in new session. Review and edit before sending." }
              } else {
                // Headless fallback
                const created = await ctx.session.create({ title: "Handoff Session" })
                await ctx.session.prompt({
                  sessionID: created.id,
                  text: fullPrompt,
                })
                return { content: `Handoff session created: ${created.id}. Open the session to continue.` }
              }
            } catch (e) {
              return { content: `Failed to create handoff session: ${e}` }
            }
          },
        })

        editor.add({
          name: "read_session",
          description: "Read the conversation transcript from a previous session.",
          input: {
            type: "object",
            properties: {
              sessionID: { type: "string", description: "The full session ID" },
              limit: { type: "number", description: "Maximum messages to read" },
            },
            required: ["sessionID"],
            additionalProperties: false,
          },
          async execute(input: any) {
            const args = input as { sessionID: string; limit?: number }
            const limit = Math.min(args.limit ?? 100, 500)
            try {
              const response = await ctx.session.context({ sessionID: args.sessionID })
              const messages = (response || []).slice(-limit)
              if (messages.length === 0) {
                return { content: "Session has no messages or does not exist." }
              }
              return { content: formatTranscript(messages, limit) }
            } catch (error) {
              const message = error instanceof Error ? error.message : "Unknown error"
              return { content: `Could not read session ${args.sessionID}: ${message}` }
            }
          },
        })
      })
    }

    // 3. Event subscription for session cleanup
    const controller = new AbortController()
    if (ctx.event?.subscribe) {
      void (async () => {
        try {
          for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
            const e = event as any
            if (e.type === "session.deleted") {
              const id = e.properties?.info?.id
              if (id) processedSessions.delete(id)
            }
          }
        } catch (error) {
          if ((error as Error).name !== "AbortError") {
            // silent exit on shutdown
          }
        }
      })()
    }

    return () => controller.abort()
  },
}
