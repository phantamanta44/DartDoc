import 'dart:io';

import 'package:args/args.dart' show ArgResults;
import 'package:discord/discord.dart' as discord;
import 'package:yaml/yaml.dart';

import 'package:dartdocbot/src/commands.dart' show Commander;
import 'package:dartdocbot/src/command_library.dart' as commandlibrary;
import 'package:dartdocbot/src/doc_parser.dart' show srcUrl, fileName, toIgnore, showDartDocsLink;

class DocBot {

  String token;
  File configFile;
  var config;
  discord.Client client;
  Commander commands;

  DocBot(ArgResults args) {
    token = args.options.contains('token') ? args['token'] : null;
    configFile = new File(args.options.contains('config') ? args['config'] : 'docbot_cfg.yml');
  }

  String init() {
    config = loadYaml(configFile.readAsStringSync());
    if (config['docsource'] == null)
      throw 'You must specify a docsource in the config file!';
    if (token == null)
      token = config['token'];
    srcUrl = 'https://github.com/${config['docsource']}/archive/${config['branch'] ?? 'master'}.zip';
    fileName = config['archive'] ?? 'doc-archive.zip';
    toIgnore = config['ignored'] != null ? new List.from(config['ignored']) : [];
    showDartDocsLink = config['showdartdocslink'] ?? false;
    client = new discord.Client(token, new discord.ClientOptions(disabledEvents: ['MESSAGE_UPDATE']));
    commandlibrary.register(commands = new Commander(this));
    client.onMessage.where((event) => event.message.content.startsWith(config['prefix'])).listen(commands.acceptEvent);
    print('Bot initialized. Waiting for authentication...');
    client.onReady.listen((e) {
      print('Bot authenticated successfully!');
      print('User: ${client.user.username}#${client.user.discriminator}');
      print('UUID: ${client.user.id}');
    });
    return null;
  }

}