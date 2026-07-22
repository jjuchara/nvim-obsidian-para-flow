local session = require("obsidian-para-flow.session")

local T = MiniTest.new_set()

local function notes()
  return {
    { path = "6. Inbox/First.md", properties = { created = "2026-07-20" } },
    { path = "6. Inbox/Second.md", properties = {} },
    { path = "6. Inbox/Third.md", properties = {} },
  }
end

T["starts with the supplied FIFO queue without retaining caller mutations"] = function()
  local source = notes()
  local review = session.new(source)
  source[1].path = "changed"

  MiniTest.expect.equality(review:current().path, "6. Inbox/First.md")
  MiniTest.expect.equality(review:snapshot(), {
    status = "active",
    current = {
      path = "6. Inbox/First.md",
      properties = { created = "2026-07-20" },
    },
    initial = 3,
    processed = 0,
    skipped = 0,
    remaining = 3,
    fully_processed = false,
    skipped_paths = {},
    actions = {},
  })
end

T["records completed actions and advances to the next note"] = function()
  local review = session.new(notes())

  review:complete("projects")
  review:complete("delete")

  MiniTest.expect.equality(review:current().path, "6. Inbox/Third.md")
  MiniTest.expect.equality(review:snapshot().processed, 2)
  MiniTest.expect.equality(review:snapshot().remaining, 1)
  MiniTest.expect.equality(review:snapshot().actions, { projects = 1, delete = 1 })

  review:complete("areas")
  MiniTest.expect.equality(review:snapshot().status, "finished")
  MiniTest.expect.equality(review:snapshot().fully_processed, true)
end

T["keeps skipped notes in session statistics but out of the remaining pass"] = function()
  local review = session.new(notes())

  review:skip()
  MiniTest.expect.equality(review:current().path, "6. Inbox/Second.md")
  MiniTest.expect.equality(review:snapshot().skipped_paths, { "6. Inbox/First.md" })

  review:complete("resources")
  review:skip()
  local snapshot = review:snapshot()
  table.sort(snapshot.skipped_paths)

  MiniTest.expect.equality(snapshot.status, "finished")
  MiniTest.expect.equality(snapshot.processed, 1)
  MiniTest.expect.equality(snapshot.skipped, 2)
  MiniTest.expect.equality(snapshot.remaining, 0)
  MiniTest.expect.equality(snapshot.fully_processed, false)
  MiniTest.expect.equality(snapshot.skipped_paths, {
    "6. Inbox/First.md",
    "6. Inbox/Third.md",
  })
end

T["distinguishes an initially empty Inbox"] = function()
  local snapshot = session.new({}):snapshot()

  MiniTest.expect.equality(snapshot.status, "finished")
  MiniTest.expect.equality(snapshot.initial, 0)
  MiniTest.expect.equality(snapshot.fully_processed, true)
  MiniTest.expect.equality(snapshot.current, nil)
end

T["pauses without consuming the current note"] = function()
  local review = session.new(notes())

  review:pause("perform_now")

  MiniTest.expect.equality(review:snapshot().status, "paused")
  MiniTest.expect.equality(review:snapshot().pause_reason, "perform_now")
  MiniTest.expect.equality(review:current().path, "6. Inbox/First.md")
  MiniTest.expect.error(function()
    review:skip()
  end)
end

T["halts in an emergency without consuming the current note"] = function()
  local review = session.new(notes())
  local details = { unapplied = { "tags" } }

  review:halt("Rollback was incomplete", details)
  details.unapplied[1] = "changed"

  local snapshot = review:snapshot()
  MiniTest.expect.equality(snapshot.status, "halted")
  MiniTest.expect.equality(snapshot.current.path, "6. Inbox/First.md")
  MiniTest.expect.equality(snapshot.emergency, {
    message = "Rollback was incomplete",
    details = { unapplied = { "tags" } },
  })
  MiniTest.expect.error(function()
    review:complete("projects")
  end)
end

T["rejects malformed queues duplicate paths and invalid transitions"] = function()
  MiniTest.expect.error(function()
    session.new(nil)
  end)
  MiniTest.expect.error(function()
    session.new({ {} })
  end)
  MiniTest.expect.error(function()
    session.new({ { path = "same" }, { path = "same" } })
  end)

  local empty = session.new({})
  MiniTest.expect.error(function()
    empty:skip()
  end)
end

return T
