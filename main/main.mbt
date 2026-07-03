fn main {
  let args = @env.args()
  if args.length() > 0 && args[0] == "--cli" {
    println("CLI mode not implemented yet")
  } else {
    println("GUI mode not implemented yet")
  }
}