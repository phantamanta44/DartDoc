import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:yaml/yaml.dart' show loadYaml;

abstract class DocObject {
  String memberName;
  String file;
  Iterable<String> modifiers;
  List<String> comment;

  get memberQuery;

  DocObject(this.memberName, this.file);

  String formatDoc();
}

class DocType extends DocObject {
  String superClass;
  Iterable<String> implemented;
  List<DocFunction> constructors;
  Map<String, DocFunction> funcs;
  Map<String, DocField> fields;

  get memberQuery => '$memberName';

  DocType(String name, String file) : super(name, file) {
    this.constructors = new List();
    this.funcs = new Map();
    this.fields = new Map();
  }

  String formatDoc() { // TODO Find better formatting method
    StringBuffer buf = new StringBuffer();

    buf..write('```dart\n');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write('class ')..write(memberName);
    if (superClass != null)
      buf..write(' extends $superClass');
    if (implemented != null)
      buf..write(' implements ${implemented.join(', ')}');
    buf..write('\n```\n');

    buf..write(comment.join('\n'))..write('\n\n');

    buf..write('**Containing File:** ')..write(file)..write('\n\n');

    if (constructors.isNotEmpty)
      buf..write('**Constructors:** ')..write(constructors.map((c) => '`${c.memberQuery}`').join(', '))..write('\n\n');

    if (funcs.isNotEmpty)
      buf..write('**Member Functions:** ')..write(funcs.values.map((f) => '`${f.memberQuery}`').join(', '))..write('\n\n');

    if (fields.isNotEmpty)
      buf..write('**Member Fields:** ')..write(fields.values.map((f) => '`${f.memberQuery}`').join(', '));

    if (showDartDocsLink && libMap.containsKey(file))
      buf..write('\n\n')..write('https://www.dartdocs.org/documentation/${pubSpec['name']}/${pubSpec['version']}/${libMap[file]}/$memberName-class.html');
    return buf.toString();
  }
}

class DocFunction extends DocObject {
  DocType parent;
  String returnType;
  String params;
  bool async;

  get memberQuery => '${parent != null ? '${parent.memberName}#' : ''}$memberName(${params})';

  DocFunction(String name, String file) : super(name, file);

  String formatDoc() { // TODO Find better formatting method
    StringBuffer buf = new StringBuffer();

    buf..write('```dart\n');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write(returnType)..write(' ')..write(memberName)
      ..write('(')..write(params)..write(')');
    if (async)
      buf..write(' async');
    buf..write('\n```\n');

    buf..write(comment.join('\n'))..write('\n\n');

    buf..write('**Containing File:** ')..write(file)..write('\n\n');

    if (parent != null)
      buf..write('**Containing Class:** ')..write('`${parent.memberQuery}`')..write('\n\n');

    if (params.isNotEmpty)
      buf..write('**Parameters:** ')..write('`$params`')..write('\n\n');

    buf..write('**Return Type:** ')..write('`$returnType`');

    if (showDartDocsLink && libMap.containsKey(file))
      buf..write('\n\n')..write('https://www.dartdocs.org/documentation/${pubSpec['name']}/${pubSpec['version']}/${libMap[file]}/${parent != null ? '${parent.memberName}/' : ''}$memberName.html');
    return buf.toString();
  }
}

class DocField extends DocObject {
  DocType parent;
  String type;

  get memberQuery => '${parent != null ? '${parent.memberName}.' : ''}$memberName';

  DocField(String name, String file) : super(name, file);

  String formatDoc() { // TODO Find better formatting method
    StringBuffer buf = new StringBuffer();

    buf..write('```dart\n');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write(type)..write(' ')..write(memberName)..write('\n```\n');

    buf..write(comment.join('\n'))..write('\n\n');

    buf..write('**Containing File:** ')..write(file)..write('\n\n');

    if (parent != null)
      buf..write('**Containing Class:** ')..write('`${parent.memberQuery}`')..write('\n\n');

    buf..write('**Static Type:** ')..write('`$type`');

    if (showDartDocsLink && libMap.containsKey(file))
      buf..write('\n\n')..write('https://www.dartdocs.org/documentation/${pubSpec['name']}/${pubSpec['version']}/${libMap[file]}/${parent != null ? '${parent.memberName}/' : ''}$memberName.html');
    return buf.toString();
  }
}

final HttpClient http = new HttpClient();
String srcUrl, fileName;
List<Pattern> toIgnore;
bool showDartDocsLink;
var pubSpec;
DateTime lastCacheTime;
Set<DocObject> cached = new Set();
Map<String, String> libMap = new Map();

Future cacheSrc() async {
  File cacheFile = new File(fileName);
  (await (await (await http.getUrl(Uri.parse(srcUrl))).close()).pipe(cacheFile.openWrite()));
  lastCacheTime = new DateTime.now();
  Archive zip = new ZipDecoder().decodeBytes(cacheFile.readAsBytesSync());
  zip.where((f) => toIgnore.every((p) => p.allMatches(f.name).isEmpty))
    .where((f) => f.name.startsWith(new RegExp(r'.+[\\/]lib[\\/]')))
    .map((f) => parse(new String.fromCharCodes(f.content), f.name.substring(f.name.lastIndexOf(new RegExp(r'[\\/]')) + 1)))
    .forEach(cached.addAll);
  pubSpec = loadYaml(new String.fromCharCodes(
      zip.firstWhere((f) => f.name.endsWith('pubspec.yaml') || f.name.endsWith('pubspec.yml')).content
  ));
}

final RegExp typeRegExp = new RegExp(r'^((?:[a-z]+ )+)?class (\w+) ?(?: extends (\w+) )?(?: implements ((?:\w+(,\s*)?)+) )?\{');
final RegExp funcRegExp = new RegExp(r'^(?!(?:(?:[a-z]+ )+)??class|part(?: of)?|get|set|return|yield)((?:[a-z]+ )*)?([\w.]+(?:<[\w.<, >]+>)? )?(?!(?:if|for|catch|while|with|super|switch|this)\W)([\w.]+)\s*\((.*)\)(?: (async))?');
final RegExp fieldRegExp = new RegExp(r'^(?!(?:(?:[a-z]+ )*)?class|part(?: of)?|get|set|return|yield|library)((?:[a-z]+ )+)?([\w.]+(?:<[\w.<, >]+>)?) (\w+(?:, \w+)*)(?:(?:.*?=(?!>))|(?!.*?\())');

Iterable<DocObject> parse(String file, String fName) {
  List<String> lines = file.split('\n');
  List<DocObject> docs = new List();
  List<String> docComment = new List();
  DocType ctx = null;
  int balance = 0;
  Match match;
  for (int i = 0; i < lines.length; i++) {
    int effectiveBalance = balance;
    if (ctx != null)
      effectiveBalance -= 1;
    String line = lines[i].trim();
    if (effectiveBalance == 0) {
      if (line.startsWith('///')) {
        docComment.add(line.substring(3).trim());
      } else if (line.startsWith('part of ')) {
        libMap[fName] = line.substring(8, line.length - 1);
      } else if ((match = typeRegExp.firstMatch(line)) != null) {
        if (!match.group(2).trim().startsWith('_')) {
          DocType doc = new DocType(match.group(2).trim(), fName);
          if (match.group(1) != null)
            doc.modifiers = match.group(1).trim().split(new RegExp(r'\s+'));
          if (match.group(3) != null)
            doc.superClass = match.group(3).trim();
          if (match.group(4) != null)
            doc.implemented = match.group(4).split(',').map((s) => s.trim());
          if (bracketBalance(line) > 0)
            ctx = doc;
          doc.comment = new List.from(docComment);
          docComment.clear();
          docs.add(doc);
        } else {
          docComment.clear();
        }
      } else if ((match = funcRegExp.firstMatch(line)) != null) {
        if (!match.group(3).trim().startsWith('_')) {
          DocFunction doc = new DocFunction(match.group(3), fName);
          if (match.group(1) != null)
            doc.modifiers = match.group(1).trim().split(new RegExp(r'\s+'));
          bool constructor = false;
          if (match.group(2) != null) {
            doc.returnType = match.group(2).trim();
          } else {
            int dotInd = doc.memberName.indexOf('.');
            if (ctx != null &&
                (doc.memberName == ctx.memberName ||
                (dotInd != -1 && doc.memberName.substring(0, dotInd) == ctx.memberName))) {
              doc.returnType = ctx.memberName;
              ctx.constructors.add(doc);
              doc.parent = ctx;
              constructor = true;
            } else {
              doc.returnType = 'dynamic';
            }
          }
          if (!constructor && ctx != null) {
            doc.parent = ctx;
            ctx.funcs[doc.memberName] = doc;
          }
          if (match.group(4) != null && match.group(4).trim().isNotEmpty)
            doc.params = parseParams(match.group(4).trim());
          else
            doc.params = '';
          doc.async = match.group(5) != null;
          doc.comment = new List.from(docComment);
          docComment.clear();
          docs.add(doc);
        } else {
          docComment.clear();
        }
      } else if ((match = fieldRegExp.firstMatch(line)) != null) {
        if (!match.group(3).trim().startsWith('_')) {
          DocField doc = new DocField(match.group(3), fName);
          if (match.group(1) != null)
            doc.modifiers = match.group(1).trim().split(new RegExp(r'\s+'));
          if (match.group(2) != null)
            doc.type = match.group(2).trim();
          else
            doc.type = 'dynamic';
          if (ctx != null) {
            doc.parent = ctx;
            ctx.fields[doc.memberName] = doc;
          }
          doc.comment = new List.from(docComment);
          docComment.clear();
          docs.add(doc);
        } else {
          docComment.clear();
        }
      }
    }
    balance += bracketBalance(line);
    if (balance == 0)
      ctx = null;
  }
  docs.forEach((d) => print(d.memberQuery));
  return docs;
}

final RegExp paramRegExp = new RegExp(r'(?!this\.)((?:^|[^\w\s.]+)\s*)(\w+)(?=\s*(?:$|[^\w\s.]+))');

String parseParams(String params) {
  return params.replaceAllMapped(paramRegExp, (m) => '${m.group(1)}dynamic ${m.group(2)}');
}

int bracketBalance(String line) {
  int balance = 0, ind = -1;
  while ((ind = line.indexOf('{', ind + 1)) != -1)
    balance++;
  ind = -1;
  while ((ind = line.indexOf('}', ind + 1)) != -1)
    balance--;
  return balance;
}

Future clearDocCache() async {
  cached.clear();
  libMap.clear();
  cacheSrc();
}

Future<Iterable<DocObject>> docFor(String query) async {
  if (lastCacheTime == null)
    await cacheSrc();
  else if (new DateTime.now().millisecondsSinceEpoch - lastCacheTime.millisecondsSinceEpoch > 1800000)
    await clearDocCache();
  return docQuery(query).allMatches();
}

final RegExp queryFuncRegExp = new RegExp(r'(?:(\w+)#)?(\w+)\((.+)?\)(?: (\w+\.dart))?');
final RegExp queryTypeFieldRegExp = new RegExp(r'(?:(\w+)\.)?(\w+)(?: (\w+\.dart))?');
final DocQuery emptyQuery = new EmptyQuery();

abstract class DocQuery {
  Iterable<DocObject> allMatches();
}

class FunctionQuery extends DocQuery {
  String containing, name, params, file;

  FunctionQuery(this.containing, this.name, this.params, this.file);

  Iterable<DocObject> allMatches() {
    Iterable<DocFunction> matches = cached.where((f) => f is DocFunction && f.memberName == this.name);
    if (this.containing == null || this.containing.trim().isEmpty)
      matches = matches.where((f) => f.parent == null);
    else
      matches = matches.where((f) => f.parent != null && f.parent.memberName == this.containing);
    if (this.params != null && this.params.isNotEmpty)
      matches = matches.where((f) => f.params == this.params);
    if (this.file != null && this.file.trim().isNotEmpty)
      matches = matches.where((f) => f.file == this.file);
    return matches;
  }
}

class FieldQuery extends DocQuery {
  String containing, name, file;

  FieldQuery(this.containing, this.name, this.file);

  Iterable<DocObject> allMatches() {
    Iterable<DocField> matches = cached.where((f) => f is DocField && f.memberName == this.name);
    if (this.containing == null || this.containing.trim().isEmpty)
      matches = matches.where((f) => f.parent == null);
    else
      matches = matches.where((f) => f.parent.memberName == this.containing);
    if (this.file != null && this.file.trim().isNotEmpty)
      matches = matches.where((f) => f.file == this.file);
    return matches;
  }
}

class NonFunctionQuery extends DocQuery {
  String name, file;

  NonFunctionQuery(this.name, this.file);

  Iterable<DocObject> allMatches() {
    Iterable<DocObject> matches = cached.where((f) => !(f is DocFunction) && f.memberName == this.name);
    if (this.file != null && this.file.trim().isNotEmpty)
      matches = matches.where((f) => f.file == this.file);
    return matches;
  }
}

class EmptyQuery extends DocQuery {
  Iterable<DocObject> allMatches() => [];
}

DocQuery docQuery(String query) {
  Match match;
  if ((match = queryFuncRegExp.firstMatch(query)) != null) {
    return new FunctionQuery(match.group(1), match.group(2), match.group(3), match.group(4));
  } else if ((match = queryTypeFieldRegExp.firstMatch(query)) != null) {
    return match.group(1) != null ? new FieldQuery(match.group(1), match.group(2), match.group(3)) : new NonFunctionQuery(match.group(2), match.group(3));
  }
  return emptyQuery;
}