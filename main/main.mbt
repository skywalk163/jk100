fn main {
  let args = @env.args()
  if args.length() > 0 && args[0] == "--cli" {
    @core.scan.run_cli()
  } else {
    @ui.views.run_gui()
  }
}
