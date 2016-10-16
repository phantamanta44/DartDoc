import 'package:discord/discord.dart';

import 'package:dartdocbot/src/commands.dart';
import 'package:dartdocbot/src/dartdocbot.dart';
import 'package:dartdocbot/src/doc_parser.dart';

void register(Commander registry) {
  registry.register(new Command('help')
    ..withDescription('Prints available commands.')
    ..withExecutor((List<String> args, Message ctx, DocBot bot) {
      String help = registry.commands.map((c) => '[ ${c.usage} ]( ${c.desc} )').join('\n');
      ctx.channel.sendMessage('```markdown\nDocBot Help\n============\n$help\n```');
    }));
  registry.register(new Command('doc')
    ..withAlias('docs')
    ..withDescription('Retrieves API documentation.')
    ..withUsage('docs <member> [srcfile]')
    ..withExecutor((List<String> args, Message ctx, DocBot bot) {
      if (args.length > 0) {
        docFor(args.join(' ')).then((docs) {
          if (docs.isEmpty) {
            ctx.channel.sendMessage('${ctx.author.mention}: No such API member `${args.join(' ')}`!');
          } else if (docs.length == 1) {
            DocObject doc = docs.first;
            ctx.channel.sendMessage('__**${doc.memberQuery}**__\n${doc.formatDoc()}');
          } else {
            Iterable<String> memberList = docs.map((d) => '- ${d.memberQuery} (${d.file})');
            ctx.channel.sendMessage('__**Matched Members**__\n${memberList.join('\n')}');
          }
        });
      } else {
        throw 'No object to look up!';
      }
    }));
  registry.register(new Command('update')
    ..withAlias('refresh')
    ..withAlias('f5')
    ..withDescription('Updates cached docs to the latest version.')
    ..withUsage('update')
    ..withExecutor((List<String> args, Message ctx, DocBot bot) {
      if (bot.config['managers'].contains(ctx.author.username)) {
        clearDocCache();
      } else {
        throw "You don't have permission to do this!";
      }
    }));
}