import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';

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
    StringBuffer buf = new StringBuffer('```markdown\n');

    buf..write('[Signature]: ');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write('class ')..write(memberName);
    if (superClass != null)
      buf..write(' extends $superClass');
    if (implemented != null)
      buf..write(' implements ${implemented.join(', ')}');
    buf..write('\n');

    buf..write('[Containing Library]: ')..write(file)..write('\n');

    if (constructors.isNotEmpty)
      buf..write('[Constructors]: ')..write(constructors.map((c) => c.memberQuery).join(', '))..write('\n');

    if (funcs.isNotEmpty)
      buf..write('[Member Functions]: ')..write(funcs.values.map((f) => f.memberQuery).join(', '))..write('\n');

    if (fields.isNotEmpty)
      buf..write('[Member Fields]: ')..write(fields.values.map((f) => f.memberQuery).join(', '))..write('\n');

    buf..write('\n')..write(comment.join('\n'))..write('\n```');
    return buf.toString();
  }
}

class DocFunction extends DocObject {
  DocType parent;
  String returnType;
  List<String> params;

  get memberQuery => '${parent != null ? '${parent.memberName}#' : ''}$memberName(${params.join(', ')})';

  DocFunction(String name, String file) : super(name, file);

  String formatDoc() { // TODO Find better formatting method
    StringBuffer buf = new StringBuffer('```markdown\n');

    buf..write('[Signature]: ');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write(returnType)..write(' ')..write(memberName)
      ..write('(')..write(params.join(', '))..write(')')..write('\n');

    buf..write('[Containing Library]: ')..write(file)..write('\n');

    if (parent != null)
      buf..write('[Containing Class]: ')..write(parent.memberName)..write('\n');

    if (params.isNotEmpty)
      buf..write('[Parameters]: ')..write(params.join(', '))..write('\n');

    buf..write('[Return Type]: ')..write(returnType)..write('\n');

    buf..write('\n')..write(comment.join('\n'))..write('\n```');
    return buf.toString();
  }
}

class DocField extends DocObject {
  DocType parent;
  String type;

  get memberQuery => '${parent != null ? '${parent.memberName}.' : ''}$memberName';

  DocField(String name, String file) : super(name, file);

  String formatDoc() { // TODO Find better formatting method
    StringBuffer buf = new StringBuffer('```markdown\n');

    buf..write('[Signature]: ');
    if (modifiers != null)
      buf..write(modifiers.join(' '))..write(' ');
    buf..write(type)..write(' ')..write(memberName)..write('\n');

    buf..write('[Containing Library]: ')..write(file)..write('\n');

    if (parent != null)
      buf..write('[Containing Class]: ')..write(parent.memberName)..write('\n');

    buf..write('[Static Type]: ')..write(type)..write('\n');

    buf..write('\n')..write(comment.join('\n'))..write('\n```');
    return buf.toString();
  }
}

final HttpClient http = new HttpClient();
String srcUrl, fileName;
DateTime lastCacheTime;
Set<DocObject> cached = new Set();

Future cacheSrc() async {
  File cacheFile = new File(fileName);
  (await (await (await http.getUrl(Uri.parse(srcUrl))).close()).pipe(cacheFile.openWrite()));
  lastCacheTime = new DateTime.now();
  new ZipDecoder().decodeBytes(cacheFile.readAsBytesSync())
    .where((f) => f.name.startsWith(new RegExp(r'.+[\\/]lib[\\/]')))
    .map((f) => parse(new String.fromCharCodes(f.content), f.name.substring(f.name.lastIndexOf(new RegExp(r'[\\/]')) + 1)))
    .forEach(cached.addAll);
}

final RegExp typeRegExp = new RegExp(r'^((?:[a-z]+ )*)class (\w+) (?:extends (\w+) )?(?:implements ((?:\w+(,\s*)?)+) )\{');
final RegExp funcRegExp = new RegExp(r'^(?!(?:(?:[a-z]+ )*)?class|part(?: of)?|get|set|return|yield)((?:[a-z]+ )*)?(\w+(?:<[\w<, >]+>)? )?(?!(?:if|for|catch|while|with|super|switch|this)\W)([\w.]+)\s*\((.*)\)');
final RegExp fieldRegExp = new RegExp(r'^(?!(?:(?:[a-z]+ )*)?class|part(?: of)?|get|set|return|yield)((?:[a-z]+ )*)?(\w+(?:<[\w<, >]+>)?) (\w+(?:, \w+)*)(?:(?:.*?=(?!>))|(?!.*?\())');
final RegExp paramRegExp = new RegExp(r'(\w+(?:<[\w<, >]+>)?) (\w+(?:, \w+)*)');

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
      } else if ((match = typeRegExp.firstMatch(line)) != null) {
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
      } else if ((match = funcRegExp.firstMatch(line)) != null) {
        DocFunction doc = new DocFunction(match.group(3), fName);
        if (match.group(1) != null)
          doc.modifiers = match.group(1).trim().split(new RegExp(r'\s+'));
        bool constructor = false;
        if (match.group(2) != null) {
          doc.returnType = match.group(2).trim();
        } else {
          int dotInd = doc.memberName.indexOf('.');
          if (ctx != null &&
              (doc.memberName == ctx.memberName
              || (dotInd != -1 && doc.memberName.substring(0, dotInd) == ctx.memberName))) {
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
          doc.params = match.group(4).split(',').map((s) => s.trim()).map((p) => paramRegExp.hasMatch(p) ? p : 'dynamic $p');
        else
          doc.params = [];
        doc.comment = new List.from(docComment);
        docComment.clear();
        docs.add(doc);
      } else if ((match = fieldRegExp.firstMatch(line)) != null) {
        DocField doc = new DocField(match.group(3), fName);
        if (match.group(1) != null)
          doc.modifiers = match.group(1).trim().split(new RegExp(r'\s+'));
        if (match.group(2) != null)
          doc.type = match.group(2).trim();
        else
          doc.type = 'dynamic';
        if (ctx != null)
          doc.parent = ctx;
        doc.comment = new List.from(docComment);
        docComment.clear();
        docs.add(doc);
      }
    }
    balance += bracketBalance(line);
    if (balance == 0)
      ctx = null;
  }
  docs.forEach((d) => print(d.memberName));
  return docs;
}

int bracketBalance(String line) {
  int balance = 0, ind = -1;
  while ((ind = line.indexOf('{', ind + 1)) != -1)
    balance++;
  while ((ind = line.indexOf('}', ind + 1)) != -1)
    balance--;
  return balance;
}

Future clearDocCache() async {
  cached.clear();
  cacheSrc();
}

Future<Iterable<DocObject>> docFor(String query) async {
  if (lastCacheTime == null)
    await cacheSrc();
  else if (new DateTime.now().millisecondsSinceEpoch - lastCacheTime.millisecondsSinceEpoch > 1800000)
    await clearDocCache();
  return docQuery(query).allMatches();
}

final RegExp queryFuncRegExp = new RegExp(r'(?:(\w+)#)?(\w+)\((.+)?\)');
final RegExp queryTypeFieldRegExp = new RegExp(r'(?:(\w+)\.)?(\w+)');
final DocQuery emptyQuery = new EmptyQuery();
final Function listEq = const ListEquality().equals;

abstract class DocQuery {
  Iterable<DocObject> allMatches();
}

class FunctionQuery extends DocQuery {
  String containing, name;
  Iterable<String> params;

  FunctionQuery(this.containing, this.name, String paramNames) {
    if (paramNames != null)
      params = paramNames.split(',').map((p) => p.trim());
  }

  Iterable<DocObject> allMatches() {
    print('$containing#$name($params)');
    Iterable<DocFunction> matches = cached.where((f) => f is DocFunction && f.memberName == this.name);
    if (this.containing == null)
      matches = matches.where((f) => f.parent == null);
    else
      matches = matches.where((f) => f.parent != null && f.parent.memberName == this.containing);
    if (this.params != null)
      matches = matches.where((f) => listEq(f.params, this.params));
    return matches;
  }
}

class FieldQuery extends DocQuery {
  String containing, name;

  FieldQuery(this.containing, this.name);

  Iterable<DocObject> allMatches() {
    return cached.where((f) => f is DocField && f.memberName == this.name);
  }
}

class NonFunctionQuery extends DocQuery {
  String name;

  NonFunctionQuery(this.name);

  Iterable<DocObject> allMatches() {
    return cached.where((f) => !(f is DocFunction) && f.memberName == this.name);
  }
}

class EmptyQuery extends DocQuery {
  Iterable<DocObject> allMatches() => [];
}

DocQuery docQuery(String query) {
  Match match;
  if ((match = queryFuncRegExp.firstMatch(query)) != null) {
    return new FunctionQuery(match.group(1), match.group(2), match.group(3));
  } else if ((match = queryTypeFieldRegExp.firstMatch(query)) != null) {
    return match.group(1) != null ? new FieldQuery(match.group(1), match.group(2)) : new NonFunctionQuery(match.group(2));
  }
  return emptyQuery;
}