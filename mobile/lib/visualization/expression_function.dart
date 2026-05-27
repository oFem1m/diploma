import 'dart:math' as math;

import 'test_functions.dart';

TestFunction compileExpressionFunction(String expression, int dims) {
  final parser = _ExpressionParser(expression, dims);
  final root = parser.parse();
  return (x) => root.eval(x);
}

abstract class _Node {
  double eval(List<double> x);
}

class _NumberNode implements _Node {
  final double value;
  _NumberNode(this.value);

  @override
  double eval(List<double> x) => value;
}

class _VariableNode implements _Node {
  final int index;
  _VariableNode(this.index);

  @override
  double eval(List<double> x) => index < x.length ? x[index] : 0;
}

class _UnaryNode implements _Node {
  final String op;
  final _Node value;
  _UnaryNode(this.op, this.value);

  @override
  double eval(List<double> x) {
    final v = value.eval(x);
    return op == '-' ? -v : v;
  }
}

class _BinaryNode implements _Node {
  final String op;
  final _Node left;
  final _Node right;
  _BinaryNode(this.op, this.left, this.right);

  @override
  double eval(List<double> x) {
    final a = left.eval(x);
    final b = right.eval(x);
    return switch (op) {
      '+' => a + b,
      '-' => a - b,
      '*' => a * b,
      '/' => a / b,
      '^' => math.pow(a, b).toDouble(),
      _ => double.nan,
    };
  }
}

class _CallNode implements _Node {
  final String name;
  final List<_Node> args;
  _CallNode(this.name, this.args);

  @override
  double eval(List<double> x) {
    final values = args.map((arg) => arg.eval(x)).toList();
    return switch (name) {
      'abs' => values[0].abs(),
      'sqrt' => math.sqrt(values[0]),
      'exp' => math.exp(values[0]),
      'log' => math.log(values[0]),
      'log10' => math.log(values[0]) / math.ln10,
      'sin' => math.sin(values[0]),
      'cos' => math.cos(values[0]),
      'tan' => math.tan(values[0]),
      'pow' => math.pow(values[0], values[1]).toDouble(),
      'min' => values.reduce(math.min),
      'max' => values.reduce(math.max),
      _ => double.nan,
    };
  }
}

class _ExpressionParser {
  final String source;
  final int dims;
  int _pos = 0;

  _ExpressionParser(this.source, this.dims);

  _Node parse() {
    final node = _parseExpression();
    _skipSpaces();
    if (!_isAtEnd) {
      throw FormatException('Unexpected token', source, _pos);
    }
    return node;
  }

  _Node _parseExpression() {
    var node = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_match('+')) {
        node = _BinaryNode('+', node, _parseTerm());
      } else if (_match('-')) {
        node = _BinaryNode('-', node, _parseTerm());
      } else {
        return node;
      }
    }
  }

  _Node _parseTerm() {
    var node = _parsePower();
    while (true) {
      _skipSpaces();
      if (!source.startsWith('**', _pos) && _match('*')) {
        node = _BinaryNode('*', node, _parsePower());
      } else if (_match('/')) {
        node = _BinaryNode('/', node, _parsePower());
      } else {
        return node;
      }
    }
  }

  _Node _parsePower() {
    var node = _parseUnary();
    _skipSpaces();
    if (_match('**') || _match('^')) {
      node = _BinaryNode('^', node, _parsePower());
    }
    return node;
  }

  _Node _parseUnary() {
    _skipSpaces();
    if (_match('+')) return _UnaryNode('+', _parseUnary());
    if (_match('-')) return _UnaryNode('-', _parseUnary());
    return _parsePrimary();
  }

  _Node _parsePrimary() {
    _skipSpaces();
    if (_match('(')) {
      final node = _parseExpression();
      _expect(')');
      return node;
    }
    if (_isDigit(_peek) || _peek == '.') return _parseNumber();
    if (_isNameStart(_peek)) return _parseName();
    throw FormatException('Expected expression', source, _pos);
  }

  _Node _parseNumber() {
    final start = _pos;
    while (_isDigit(_peek)) {
      _pos++;
    }
    if (_peek == '.') {
      _pos++;
      while (_isDigit(_peek)) {
        _pos++;
      }
    }
    if (_peek == 'e' || _peek == 'E') {
      _pos++;
      if (_peek == '+' || _peek == '-') _pos++;
      while (_isDigit(_peek)) {
        _pos++;
      }
    }
    return _NumberNode(double.parse(source.substring(start, _pos)));
  }

  _Node _parseName() {
    final start = _pos;
    _pos++;
    while (_isNamePart(_peek)) {
      _pos++;
    }
    final name = source.substring(start, _pos);
    if (name == 'pi') return _NumberNode(math.pi);
    if (name == 'e') return _NumberNode(math.e);
    if (name.startsWith('x')) {
      final index = int.tryParse(name.substring(1));
      if (index != null && index >= 0 && index < dims) {
        return _VariableNode(index);
      }
    }
    _skipSpaces();
    if (!_match('(')) {
      throw FormatException('Unknown name: $name', source, start);
    }
    final args = <_Node>[];
    _skipSpaces();
    if (!_match(')')) {
      while (true) {
        args.add(_parseExpression());
        _skipSpaces();
        if (_match(')')) break;
        _expect(',');
      }
    }
    _validateCall(name, args.length, start);
    return _CallNode(name, args);
  }

  void _validateCall(String name, int argCount, int position) {
    final unary = {'abs', 'sqrt', 'exp', 'log', 'log10', 'sin', 'cos', 'tan'};
    if (unary.contains(name) && argCount == 1) return;
    if (name == 'pow' && argCount == 2) return;
    if ((name == 'min' || name == 'max') && argCount >= 1) return;
    throw FormatException('Invalid function call: $name', source, position);
  }

  void _expect(String value) {
    _skipSpaces();
    if (!_match(value)) {
      throw FormatException('Expected $value', source, _pos);
    }
  }

  bool _match(String value) {
    if (source.startsWith(value, _pos)) {
      _pos += value.length;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (!_isAtEnd && source.codeUnitAt(_pos) <= 32) {
      _pos++;
    }
  }

  String get _peek => _isAtEnd ? '' : source[_pos];
  bool get _isAtEnd => _pos >= source.length;

  bool _isDigit(String value) {
    if (value.isEmpty) return false;
    final code = value.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }

  bool _isNameStart(String value) {
    if (value.isEmpty) return false;
    final code = value.codeUnitAt(0);
    return (code >= 65 && code <= 90) ||
        (code >= 97 && code <= 122) ||
        value == '_';
  }

  bool _isNamePart(String value) => _isNameStart(value) || _isDigit(value);
}
