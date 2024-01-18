import ArgumentParser

@main
struct ProxyCLI: AsyncParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A utility for performing maths.",
        subcommands: [SysExt.self, Proxy.self])
}
