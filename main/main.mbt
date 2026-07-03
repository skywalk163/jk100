fn main {
  let args = @env.args()
  if args.length() > 0 && args[0] == "--cli" {
    @core.run_cli()
  } else {
    @ui.run_gui()
  }
}
