const std = @import("std");
const Discord = @import("discord");
const Shard = Discord.Shard;

const CACommand = Discord.CreateApplicationCommand;
const AppCommand = Discord.ApplicationCommand;

var session: *Discord.Session = undefined;

fn ready(_: *Shard, payload: Discord.Ready) !void {
    std.debug.print("logged in as {s}\n", .{payload.user.username});
}

fn message_create(_: *Shard, message: Discord.Message) !void {
    if (message.content != null and std.ascii.eqlIgnoreCase(message.content.?, "!hi")) {
        var result = try session.api.sendMessage(message.channel_id, .{ .content = "hi :)" });
        defer result.deinit();

        const m = result.value.unwrap();
        std.debug.print("sent: {?s}\n", .{m.content});
    }
}

const ping_cmd: CACommand = CACommand{
    .type = Discord.ApplicationCommandTypes.ChatInput,
    .name = "ping",
    .version = "0.1.0",
    .contexts = Discord.InteractionContextType.Guild,
    .description = "Replies with Pong!",
    .dm_permission = true,
    .nsfw = false,
};

fn ping_command(_: *Shard, message: Discord.MessageInteraction) !void {
    var res = try session.api.sendMessage(message.id, .{ .content = "Pong!" });
    defer res.deinit();

    const msg = res.value.unwrap();
    std.debug.print("sent: {?s}\n", .{msg.content});
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    const allocator = gpa.allocator();

    session = try allocator.create(Discord.Session);
    session.* = Discord.init(allocator);
    defer session.deinit();

    const env_map = try allocator.create(std.process.EnvMap);
    env_map.* = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const token = env_map.get("DISCORD_TOKEN") orelse {
        @panic("DISCORD_TOKEN not found in environment variables");
    };

    const intents = comptime blk: {
        var bits: Discord.Intents = .{};
        bits.Guilds = true;
        bits.GuildMessages = true;
        bits.GuildMembers = true;
        break :blk bits;
    };

    try session.start(.{
        .intents = intents,
        .authorization = token,
        .run = .{ .message_create = &message_create, .ready = &ready, .interaction_create = &ping_command },
        .log = .yes,
        .options = .{},
        .cache = .defaults(allocator),
    });
}
