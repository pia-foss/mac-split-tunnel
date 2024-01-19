import ArgumentParser

@main
struct ProxyCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Simple CLI tool to manage the proxy system extension.",
        subcommands: [SysExt.self, Proxy.self])
}
