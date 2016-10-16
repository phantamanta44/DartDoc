import 'package:discord/discord.dart';

import 'package:dartdocbot/src/dartdocbot.dart' show DocBot;

class Commander {
  List<Command> commands;
  Map<String, int> aliases;
  DocBot bot;

  Commander(this.bot) {
    this.commands = [];
    this.aliases = {};
  }

  void register(Command cmd) {
    final int ind = commands.length;
    commands.add(cmd);
    cmd.aliases.forEach((alias) => aliases[alias] = ind);
    aliases[cmd.name] = ind;
  }

  void acceptEvent(MessageEvent event) {
    try {
      String source = event.message.guild != null ? event.message.guild.name : 'PM';
      print('$source / ${event.message.author.username}: ${event.message.content}');
      parse(event.message);
    } catch (e) {
      event.message.channel.sendMessage('${event.message.author.mention}: $e');
    }
  }

  void parse(Message message) {
    String text = message.content.substring(bot.config['prefix'].length).trim();
    List<String> parts = text.split(new RegExp(r'\s'));
    if (!aliases.containsKey(parts[0]))
      throw 'No such command `${parts[0]}`! Try using `${bot.config['prefix']}help`.';
    commands[aliases[parts[0]]](parts.sublist(1), message, bot);
  }
}

class Command {
  final String name;
  String desc, _usage;
  Function exec;
  List<String> aliases;

  get usage => _usage ?? name;

  Command(this.name) {
    this.aliases = [];
  }

  void withDescription(String desc) {
    this.desc = desc;
  }

  void withUsage(String usage) {
    this._usage = usage;
  }

  void withExecutor(List<String> exec(List<String> args, Message ctx, DocBot bot)) {
    this.exec = exec;
  }

  void withAlias(String alias) => this.aliases.add(alias);

  void call(List<String> args, Message ctx, DocBot bot) => this.exec(args, ctx, bot);
}