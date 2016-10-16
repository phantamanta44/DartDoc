import 'dart:io' show exit;

import 'package:args/args.dart' show ArgParser;

import 'package:dartdocbot/src/dartdocbot.dart' show DocBot;

main(List<String> args) {
  ArgParser parser = new ArgParser()
    ..addOption('token', abbr: 't')
    ..addOption('config', abbr: 'c');
  DocBot bot = new DocBot(parser.parse(args));
  try {
    bot.init();
  } catch (e) {
    print('Something went wrong!');
    print(e);
    exit(1);
  }
}
