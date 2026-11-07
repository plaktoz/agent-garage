---
name: ste-docs
description: Write a document about one subject in controlled plain English (ASD-STE100 style) with Mermaid diagrams, as one Markdown file. Has a technical profile (fixed 8-section layout) for a mod, skill, agent, hook or other code. Use when asked to document a subject in this style.
---

# ste-docs

Writes one document about one subject. The output is one `.md` file in the subject's folder. The file does not need an HTML copy, because a Markdown viewer shows the same content.

The subject decides the content. The writing rules, the diagram rules and the checks stay the same for every subject. A profile adds a layout and extra checks for one kind of subject.

## 1. Profiles

Choose the profile from the subject:

| Profile | Use for | File |
|---------|---------|------|
| Technical | A mod, skill, agent, hook, script or library. Any subject that is code or a tool. | `technical.md` in this folder |
| General | Any other subject. For example a guide, a policy or a proposal. | None. Use this file only. |

- For the technical profile, read `technical.md` before you write. It sets the fixed layout, the file name (`README.md`) and the code checks.
- For the general profile, agree the outline with the user before you write. Name the file after the document, in the folder the user names. Use `README.md` only if the document is the README of a folder.
- If the profile is not clear, ask the user. Do not guess.

## 2. Inputs

- The subject folder, or the file that the user names. Ask only if the subject cannot be found.
- Read every source that defines the content. Do not write from memory.

## 3. Writing rules (controlled English)

1. One instruction or fact per sentence.
2. Keep each sentence to 20 words or fewer.
3. Use the active voice. Write subject, verb, object.
4. Write steps in the imperative: "Run the command." Do not write "You should run the command."
5. Use the present tense.
6. Use one word for one meaning. Use the same term everywhere. Do not use a synonym for a term already defined.
7. Use `must` for a requirement. Use `can` for an ability. Use `do not` for a prohibition.
8. Do not use idioms, contractions, or "etc.".
9. Write numbers with digits and a unit. Example: `5 minutes`, `250,000 tokens`.
10. Write each list item in the same grammatical form.
11. Check every word against `banned-words.md` in this folder. Replace each hit with the word in its right-hand column. Then reread the sentence.

Use a glossary for every domain term. Define each term once.

## 4. Diagrams

- Draw a diagram only when a mechanism is hard to follow in text. Good cases: a flow with branches, a set of states, and a sequence of calls between parts. Do not add decoration.
- Choose the diagram type from the content:
  - Flowchart for decisions and flows.
  - State diagram for states and transitions.
  - Sequence diagram for calls between parts.
- Write each diagram as a Mermaid code fence in the `.md` file.
- A picture that has no Mermaid form must be redrawn as Mermaid, or left out.
- Put each diagram under the section it explains. Write a caption line under the fence. Number the figures in order: `Figure 1.`, `Figure 2.` and so on.
- Describe the flow of each diagram in one sentence of text next to it. A reader who cannot see the picture must still get the flow.
- Highlight at most one path per diagram. The highlighted path is the one the reader must notice. Use a thicker line (`linkStyle`), not a color. The theme of the viewer must control all colors.

## 5. Honesty

- Say what was not run. If a check was not run, write that in the document.
- For a step that only a person can do, write: "No person has done this check yet."
- Write "passed" only when a command printed it.
- Do not state a fact that the sources do not show.

## 6. Verification (required before the report)

Run each check. Report the real output. For the technical profile, also run the checks in `technical.md`.

1. For each `](#name)` link in the file, check that a heading exists whose anchor is `name`.
2. Search the file for each banned word, as a whole word, case-insensitive. Expect zero hits.
3. Check that each Mermaid block starts with a diagram type: `flowchart`, `stateDiagram-v2` or `sequenceDiagram`.
4. If the `mmdc` command is installed, run it on each Mermaid block and report the result. If it is not installed, write "Mermaid syntax not checked: `mmdc` is not installed."

## 7. Report

Report these items:

- The path of the file.
- The real output of each check in section 6.
- Each check that was not run, and why.
- Open questions for the user.

Do not commit unless the user asks.
