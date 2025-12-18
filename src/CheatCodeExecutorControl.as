package
{
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.InteractiveObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.FileFilter;
	import flash.net.FileReference;
	import flash.net.SharedObject;
	import flash.system.ApplicationDomain;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.utils.Dictionary;
	import flash.utils.setTimeout;
	
	public class CheatCodeExecutorControl extends Sprite
	{
		// ===== Token types =====
		private static const TK_ID:String = "ID";
		private static const TK_NUM:String = "NUM";
		private static const TK_STR:String = "STR";
		private static const TK_OP:String = "OP";
		private static const TK_PUNC:String = "PUNC";
		private static const TK_KW:String = "KW";
		private static const TK_EOF:String = "EOF";
		
		private static const SOL_NAME:String = "CheatCodeExecutorControl";
		private static const SOL_KEY_SCRIPT:String = "savedScript";
		
		private static const BUILTIN_NOT_MATCHED:Object = {};
		
		private static const SIG_NONE:int = 0;
		private static const SIG_RETURN:int = 1;
		private static const SIG_BREAK:int = 2;
		private static const SIG_CONTINUE:int = 3;
		
		private static const SIG_BREAK_OBJ:Object = {sig: SIG_BREAK};
		private static const SIG_CONTINUE_OBJ:Object = {sig: SIG_CONTINUE};
		private const _builtinNames:Object = {"delay": true, "log": true, "click": true, "getcolor": true};
		
		// ===== pkgChain placeholder (NEW) =====
		private static const PKGCHAIN_TAG:String = "__pkgChain__";
		
		private function makePkgChain(node:Object):Object
		{
			var o:Object = {};
			o[PKGCHAIN_TAG] = true;
			o.node = node;
			return o;
		}
		
		private function isPkgChain(v:*):Boolean
		{
			return (v != null) && (v is Object) && Object(v).hasOwnProperty(PKGCHAIN_TAG) && Object(v)[PKGCHAIN_TAG] === true;
		}
		
		/** 只有真正需要这个值时才解析；失败才按 logOnFail 打日志 */
		private function consumeValue(v:*, logOnFail:Boolean):*
		{
			if (!isPkgChain(v)) return v;
			var node:Object = Object(v).node;
			var expr:String = buildChainString(node);
			return evalExpression2(expr, logOnFail);
		}
		
		// ===== UI / persistence =====
		private var _so:SharedObject;
		
		private var _loadBtn:Sprite;
		private var _loadBtnLabel:TextField;
		private var _fileRef:FileReference;
		
		private var _saveBtn:Sprite;
		private var _saveBtnLabel:TextField;
		
		private var _input:TextField;
		
		private var _btn:Sprite;
		private var _btnLabel:TextField;
		
		// ===== Runtime =====
		private var _env:Dictionary = new Dictionary();
		private var _envStack:Array = [];
		
		private var _toks:Array;
		private var _pos:int;
		
		private var _frames:Array = [];
		private var _valueStack:Array = [];
		
		private var _isPaused:Boolean = false;
		private var _runningAst:Object = null;
		
		private var _steps:int = 0;
		private const MAX_STEPS:int = 200000;
		
		private var _importMap:Object = {}; // alias -> fullName
		
		private var _pkgRootCache:Object = {};       // name -> Boolean
		private var _classCache:Object = {};         // className -> Class
		private var _classResolveCache:Object = {};  // key(expr[0:searchEnd]) -> {className:String, classEnd:int}
		
		public function CheatCodeExecutorControl()
		{
			super();
			buildUI();
			loadScriptFromSOL();
		}
		
		// =====================================================================
		// UI
		// =====================================================================
		
		private function buildUI():void
		{
			_input = new TextField();
			_input.type = TextFieldType.INPUT;
			_input.border = true;
			_input.background = true;
			_input.backgroundColor = 2763306;
			var tfInput:TextFormat = new TextFormat("宋体", 12, 16777215);
			_input.defaultTextFormat = tfInput;
			_input.width = 280;
			_input.height = 110;
			_input.multiline = true;
			_input.wordWrap = true;
			_input.x = 0;
			_input.y = 0;
			
			_input.text = "function t(){\n" + "  log(\"enter\");\n" + "  delay(1000);\n" + "  log(\"return\");\n" + "  return 5;\n" + "}\n" + "log(t());\n";
			
			addChild(_input);
			
			_btn = new Sprite();
			_btn.graphics.beginFill(4473924, 1);
			_btn.graphics.drawRoundRect(0, 0, 80, 22, 8, 8);
			_btn.graphics.endFill();
			_btn.buttonMode = true;
			_btn.mouseChildren = false;
			_btn.x = 0;
			_btn.y = _input.y + _input.height + 4;
			addChild(_btn);
			
			_btnLabel = new TextField();
			var tfBtn:TextFormat = new TextFormat("宋体", 12, 16777215, true);
			tfBtn.align = "center";
			_btnLabel.defaultTextFormat = tfBtn;
			_btnLabel.width = 80;
			_btnLabel.height = 20;
			_btnLabel.x = 0;
			_btnLabel.y = 1;
			_btnLabel.selectable = false;
			_btnLabel.text = "执行脚本";
			_btn.addChild(_btnLabel);
			_btn.addEventListener(MouseEvent.CLICK, onExecuteClick);
			
			_saveBtn = new Sprite();
			_saveBtn.graphics.beginFill(4473924, 1);
			_saveBtn.graphics.drawRoundRect(0, 0, 80, 22, 8, 8);
			_saveBtn.graphics.endFill();
			_saveBtn.buttonMode = true;
			_saveBtn.mouseChildren = false;
			_saveBtn.x = _btn.x + _btn.width + 6;
			_saveBtn.y = _btn.y;
			addChild(_saveBtn);
			
			_saveBtnLabel = new TextField();
			var tfSave:TextFormat = new TextFormat("宋体", 12, 16777215, true);
			tfSave.align = "center";
			_saveBtnLabel.defaultTextFormat = tfSave;
			_saveBtnLabel.width = 80;
			_saveBtnLabel.height = 20;
			_saveBtnLabel.x = 0;
			_saveBtnLabel.y = 1;
			_saveBtnLabel.selectable = false;
			_saveBtnLabel.text = "保存脚本";
			_saveBtn.addChild(_saveBtnLabel);
			_saveBtn.addEventListener(MouseEvent.CLICK, onSaveClick);
			
			_input.addEventListener(FocusEvent.FOCUS_IN, onInputFocusIn);
			_input.addEventListener(FocusEvent.FOCUS_OUT, onInputFocusOut);
			
			_loadBtn = new Sprite();
			_loadBtn.graphics.beginFill(4473924, 1);
			_loadBtn.graphics.drawRoundRect(0, 0, 100, 22, 8, 8);
			_loadBtn.graphics.endFill();
			_loadBtn.buttonMode = true;
			_loadBtn.mouseChildren = false;
			_loadBtn.x = _saveBtn.x + _saveBtn.width + 6;
			_loadBtn.y = _btn.y;
			addChild(_loadBtn);
			
			_loadBtnLabel = new TextField();
			var tfLoad:TextFormat = new TextFormat("宋体", 12, 16777215, true);
			tfLoad.align = "center";
			_loadBtnLabel.defaultTextFormat = tfLoad;
			_loadBtnLabel.width = 100;
			_loadBtnLabel.height = 20;
			_loadBtnLabel.x = 0;
			_loadBtnLabel.y = 1;
			_loadBtnLabel.selectable = false;
			_loadBtnLabel.text = "读取本地脚本";
			_loadBtn.addChild(_loadBtnLabel);
			_loadBtn.addEventListener(MouseEvent.CLICK, onLoadClick);
		}
		
		private function onLoadClick(e:MouseEvent):void
		{
			_fileRef = new FileReference();
			_fileRef.addEventListener(Event.SELECT, onFileSelected);
			_fileRef.addEventListener(Event.CANCEL, onFileCancel);
			
			var filters:Array = [new FileFilter("Text Files (*.txt)", "*.txt")];
			_fileRef.browse(filters);
		}
		
		private function onFileSelected(e:Event):void
		{
			_fileRef.removeEventListener(Event.SELECT, onFileSelected);
			_fileRef.removeEventListener(Event.CANCEL, onFileCancel);
			
			_fileRef.addEventListener(Event.COMPLETE, onFileLoaded);
			_fileRef.addEventListener(IOErrorEvent.IO_ERROR, onFileLoadError);
			
			try
			{
				_fileRef.load();
			}
			catch (err:Error)
			{
				CheatPanel.log("代码执行器：读取文件失败：" + err.message);
				cleanupFileRef();
			}
		}
		
		private function onFileLoaded(e:Event):void
		{
			var data:String = "";
			try
			{
				data = _fileRef.data.toString();
			}
			catch (err:Error)
			{
				CheatPanel.log("代码执行器：文件内容解析失败：" + err.message);
				cleanupFileRef();
				return;
			}
			
			if (data != null)
			{
				data = data.replace(/[\r\n]/g, "\n");
				_input.text = data;
				CheatPanel.log("代码执行器：脚本已从本地加载。");
			}
			
			cleanupFileRef();
		}
		
		private function onFileLoadError(e:IOErrorEvent):void
		{
			CheatPanel.log("代码执行器：读取文件 IO 错误：" + e.text);
			cleanupFileRef();
		}
		
		private function onFileCancel(e:Event):void
		{
			cleanupFileRef();
		}
		
		private function cleanupFileRef():void
		{
			if (!_fileRef) return;
			_fileRef.removeEventListener(Event.COMPLETE, onFileLoaded);
			_fileRef.removeEventListener(IOErrorEvent.IO_ERROR, onFileLoadError);
			_fileRef = null;
		}
		
		private function onInputFocusIn(e:FocusEvent):void
		{
			if (stage)
			{
				stage.addEventListener(KeyboardEvent.KEY_DOWN, blockKeyEvent, true);
				stage.addEventListener(KeyboardEvent.KEY_UP, blockKeyEvent, true);
			}
		}
		
		private function onInputFocusOut(e:FocusEvent):void
		{
			if (stage)
			{
				stage.removeEventListener(KeyboardEvent.KEY_DOWN, blockKeyEvent, true);
				stage.removeEventListener(KeyboardEvent.KEY_UP, blockKeyEvent, true);
			}
		}
		
		private function blockKeyEvent(e:KeyboardEvent):void
		{
			if (stage && stage.focus == _input)
			{
				e.stopImmediatePropagation();
			}
		}
		
		private function onSaveClick(e:MouseEvent):void
		{
			saveScriptToSOL();
			CheatPanel.log("代码执行器：脚本已保存。");
		}
		
		private function loadScriptFromSOL():void
		{
			try
			{
				_so = SharedObject.getLocal(SOL_NAME);
				if (_so.data.hasOwnProperty(SOL_KEY_SCRIPT))
				{
					var saved:String = String(_so.data[SOL_KEY_SCRIPT]);
					if (saved && saved.replace(/\s+/g, "") != "")
					{
						_input.text = saved;
					}
				}
			}
			catch (err:Error)
			{
			}
		}
		
		private function saveScriptToSOL():void
		{
			try
			{
				if (!_so) _so = SharedObject.getLocal(SOL_NAME);
				_so.data[SOL_KEY_SCRIPT] = _input.text;
				_so.flush();
			}
			catch (err:Error)
			{
			}
		}
		
		override public function get height():Number
		{
			return _btn.y + _btn.height;
		}
		
		private function onExecuteClick(e:MouseEvent):void
		{
			var cmd:String = _input.text;
			if (!cmd || cmd.replace(/\s+/g, "") == "")
			{
				CheatPanel.log("代码执行器：输入为空。");
				return;
			}
			try
			{
				executeCommand(cmd);
			}
			catch (err:Error)
			{
				CheatPanel.log("代码执行器：执行过程中异常：\n" + err.name + ": " + err.message);
			}
		}
		
		// =====================================================================
		// Entry
		// =====================================================================
		
		private function executeCommand(cmd:String):void
		{
			cmd = cmd.replace(/[\r\n]/g, "\n");
			
			_steps = 0;
			_isPaused = false;
			
			_importMap = {};
			_pkgRootCache = {};
			_classCache = {};
			_classResolveCache = {};
			
			var tokens:Array = tokenize(cmd);
			var ast:Object = parseProgram(tokens);
			
			runProgram(ast);
		}
		
		// =====================================================================
		// Tokenizer
		// =====================================================================
		
		private function tokenize(src:String):Array
		{
			var tokens:Array = [];
			var i:int = 0;
			
			while (i < src.length)
			{
				var ch:String = src.charAt(i);
				
				if (ch <= " ")
				{
					i++;
					continue;
				}
				
				// // comment
				if (i + 1 < src.length && src.charAt(i) == "/" && src.charAt(i + 1) == "/")
				{
					i += 2;
					while (i < src.length)
					{
						ch = src.charAt(i);
						if (ch == "\n" || ch == "\r") break;
						i++;
					}
					continue;
				}
				
				// number
				if (ch >= "0" && ch <= "9")
				{
					var j:int = i + 1;
					while (j < src.length)
					{
						var cj:String = src.charAt(j);
						if (!((cj >= "0" && cj <= "9") || cj == "."))
						{
							break;
						}
						j++;
					}
					tokens.push({type: TK_NUM, value: src.substring(i, j)});
					i = j;
					continue;
				}
				
				// identifier (supports chinese/non-ascii)
				if (isIdentStart(src.charCodeAt(i)))
				{
					j = i + 1;
					while (j < src.length && isIdentPart(src.charCodeAt(j)))
					{
						j++;
					}
					
					var word:String = src.substring(i, j);
					var kw:Boolean = word == "var" || word == "if" || word == "else" || word == "while" || word == "true" || word == "false" || word == "null" || word == "function" || word == "return" || word == "break" || word == "continue" || word == "import" || word == "as" || word == "new";
					
					tokens.push({type: (kw ? TK_KW : TK_ID), value: word});
					i = j;
					continue;
				}
				
				// string
				if (ch == "\"" || ch == "'")
				{
					var quote:String = ch;
					j = i + 1;
					var buf:String = "";
					while (j < src.length)
					{
						ch = src.charAt(j);
						if (ch == "\\")
						{
							if (j + 1 < src.length)
							{
								buf += src.charAt(j + 1);
								j += 2;
								continue;
							}
						}
						if (ch == quote) break;
						buf += ch;
						j++;
					}
					tokens.push({type: TK_STR, value: buf});
					i = j + 1;
					continue;
				}
				
				// two-char operators
				var two:String = (i + 1 < src.length) ? src.substr(i, 2) : "";
				if (two == "==" || two == "!=" || two == "<=" || two == ">=" || two == "&&" || two == "||")
				{
					tokens.push({type: TK_OP, value: two});
					i += 2;
					continue;
				}
				
				// one-char operators
				if ("+-*/%=<>!".indexOf(ch) >= 0)
				{
					tokens.push({type: TK_OP, value: ch});
					i++;
					continue;
				}
				
				// punctuation
				if ("(){};,.[]:".indexOf(ch) >= 0)
				{
					tokens.push({type: TK_PUNC, value: ch});
					i++;
					continue;
				}
				
				CheatPanel.log("Tokenizer: 非法字符: " + ch);
				i++;
			}
			
			tokens.push({type: TK_EOF, value: ""});
			return tokens;
		}
		
		private function isIdentStart(cc:int):Boolean
		{
			if ((cc >= 65 && cc <= 90) || (cc >= 97 && cc <= 122) || cc == 95 || cc == 36) return true;
			if (cc >= 0x4E00 && cc <= 0x9FFF) return true;
			if (cc >= 0x80)
			{
				if (cc == 0x3000) return false;
				return true;
			}
			return false;
		}
		
		private function isIdentPart(cc:int):Boolean
		{
			if (isIdentStart(cc)) return true;
			if (cc >= 48 && cc <= 57) return true;
			return false;
		}
		
		// =====================================================================
		// Parser
		// =====================================================================
		
		private function peek():Object  { return _toks[_pos]; }
		
		private function nextTok():Object  { return _toks[_pos++]; }
		
		private function match(type:String, value:String = null):Boolean
		{
			var t:Object = peek();
			if (t.type != type) return false;
			if (value != null && t.value != value) return false;
			_pos++;
			return true;
		}
		
		private function expect(type:String, value:String = null):Object
		{
			var t:Object = peek();
			if (!match(type, value))
			{
				throw new Error("Parse error: expect " + type + " " + value + " but got " + t.type + " " + t.value);
			}
			return t;
		}
		
		private function parseProgram(tokens:Array):Object
		{
			_toks = tokens;
			_pos = 0;
			var body:Array = [];
			while (peek().type != TK_EOF)
			{
				body.push(parseStatement());
			}
			return {type: "Program", body: body};
		}
		
		private function parseStatement():Object
		{
			var t:Object = peek();
			
			if (t.type == TK_KW && t.value == "import")
			{
				nextTok();
				var parts:Array = [];
				var first:Object = expect(TK_ID);
				parts.push(first.value);
				while (match(TK_PUNC, "."))
				{
					var seg:Object = expect(TK_ID);
					parts.push(seg.value);
				}
				var alias:String = parts[parts.length - 1];
				if (peek().type == TK_KW && peek().value == "as")
				{
					nextTok();
					alias = expect(TK_ID).value;
				}
				expect(TK_PUNC, ";");
				_importMap[alias] = parts.join(".");
				return {type: "ImportDecl"};
			}
			
			if (match(TK_PUNC, "{"))
			{
				var stmts:Array = [];
				while (!match(TK_PUNC, "}"))
				{
					stmts.push(parseStatement());
				}
				return {type: "Block", body: stmts};
			}
			
			if (t.type == TK_KW && t.value == "var")
			{
				nextTok();
				var idTok:Object = expect(TK_ID);
				var init:Object = null;
				if (match(TK_OP, "="))
				{
					init = parseExpression();
				}
				expect(TK_PUNC, ";");
				return {type: "VarDecl", name: idTok.value, init: init};
			}
			
			if (t.type == TK_KW && t.value == "if")
			{
				nextTok();
				expect(TK_PUNC, "(");
				var test:Object = parseExpression();
				expect(TK_PUNC, ")");
				var cons:Object = parseStatement();
				var alt:Object = null;
				if (peek().type == TK_KW && peek().value == "else")
				{
					nextTok();
					alt = parseStatement();
				}
				return {type: "If", test: test, cons: cons, alt: alt};
			}
			
			if (t.type == TK_KW && t.value == "while")
			{
				nextTok();
				expect(TK_PUNC, "(");
				test = parseExpression();
				expect(TK_PUNC, ")");
				var body:Object = parseStatement();
				return {type: "While", test: test, body: body};
			}
			
			if (t.type == TK_KW && t.value == "function")
			{
				nextTok();
				var fnNameTok:Object = expect(TK_ID);
				expect(TK_PUNC, "(");
				var params:Array = [];
				if (!match(TK_PUNC, ")"))
				{
					do
					{
						var pTok:Object = expect(TK_ID);
						params.push(pTok.value);
					} while (match(TK_PUNC, ","));
					expect(TK_PUNC, ")");
				}
				var fnBody:Object = parseStatement();
				return {type: "FunctionDecl", name: fnNameTok.value, params: params, body: fnBody};
			}
			
			if (t.type == TK_KW && t.value == "return")
			{
				nextTok();
				var arg:Object = null;
				if (!match(TK_PUNC, ";"))
				{
					arg = parseExpression();
					expect(TK_PUNC, ";");
				}
				return {type: "Return", arg: arg};
			}
			
			if (t.type == TK_KW && t.value == "break")
			{
				nextTok();
				expect(TK_PUNC, ";");
				return {type: "Break"};
			}
			
			if (t.type == TK_KW && t.value == "continue")
			{
				nextTok();
				expect(TK_PUNC, ";");
				return {type: "Continue"};
			}
			
			var expr:Object = parseExpression();
			if (match(TK_OP, "="))
			{
				var right:Object = parseExpression();
				expect(TK_PUNC, ";");
				return {type: "Assign", left: expr, right: right};
			}
			
			expect(TK_PUNC, ";");
			return {type: "ExprStmt", expr: expr};
		}
		
		private function prec(op:String):int
		{
			switch (op)
			{
			case "||": 
				return 1;
			case "&&": 
				return 2;
			case "==": 
			case "!=": 
				return 3;
			case "<": 
			case ">": 
			case "<=": 
			case ">=": 
				return 4;
			case "+": 
			case "-": 
				return 5;
			case "*": 
			case "/": 
			case "%": 
				return 6;
			default: 
				return 0;
			}
		}
		
		private function parseExpression(minPrec:int = 1):Object
		{
			var left:Object = parseUnary();
			while (peek().type == TK_OP && prec(peek().value) >= minPrec)
			{
				var opTok:Object = nextTok();
				var op:String = opTok.value;
				var right:Object = parseExpression(prec(op) + 1);
				left = {type: "Binary", op: op, left: left, right: right};
			}
			return left;
		}
		
		private function parseUnary():Object
		{
			if (peek().type == TK_OP && (peek().value == "!" || peek().value == "-"))
			{
				var op:String = nextTok().value;
				var arg:Object = parseUnary();
				return {type: "Unary", op: op, arg: arg};
			}
			return parsePrimary();
		}
		
		private function parsePrimary():Object
		{
			var t:Object = peek();
			
			// new
			if (t.type == TK_KW && t.value == "new")
			{
				nextTok();
				var idTok:Object = expect(TK_ID);
				var target:Object = {type: "Name", value: idTok.value};
				
				while (true)
				{
					if (match(TK_PUNC, "."))
					{
						var propTok:Object = expect(TK_ID);
						target = {type: "Member", object: target, prop: propTok.value};
						continue;
					}
					if (match(TK_PUNC, "["))
					{
						var indexExpr:Object = parseExpression();
						expect(TK_PUNC, "]");
						target = {type: "Index", object: target, index: indexExpr};
						continue;
					}
					break;
				}
				
				var args:Array = [];
				if (match(TK_PUNC, "("))
				{
					if (!match(TK_PUNC, ")"))
					{
						do
						{
							args.push(parseExpression());
						} while (match(TK_PUNC, ","));
						expect(TK_PUNC, ")");
					}
				}
				return {type: "New", callee: target, args: args};
			}
			
			if (match(TK_NUM))
			{
				return {type: "Literal", value: Number(t.value)};
			}
			if (match(TK_STR))
			{
				return {type: "Literal", value: String(t.value)};
			}
			if (t.type == TK_KW && (t.value == "true" || t.value == "false" || t.value == "null"))
			{
				nextTok();
				var v:* = (t.value == "true") ? true : ((t.value == "false") ? false : null);
				return {type: "Literal", value: v};
			}
			if (match(TK_PUNC, "("))
			{
				var e:Object = parseExpression();
				expect(TK_PUNC, ")");
				return e;
			}
			if (match(TK_PUNC, "["))
			{
				var elements:Array = [];
				if (!match(TK_PUNC, "]"))
				{
					do
					{
						elements.push(parseExpression());
					} while (match(TK_PUNC, ","));
					expect(TK_PUNC, "]");
				}
				return {type: "ArrayLiteral", elements: elements};
			}
			
			var nameTok:Object = expect(TK_ID);
			var node:Object = {type: "Name", value: nameTok.value};
			
			while (true)
			{
				if (match(TK_PUNC, "."))
				{
					var pt:Object = expect(TK_ID);
					node = {type: "Member", object: node, prop: pt.value};
					continue;
				}
				if (match(TK_PUNC, "["))
				{
					var ie:Object = parseExpression();
					expect(TK_PUNC, "]");
					node = {type: "Index", object: node, index: ie};
					continue;
				}
				if (match(TK_PUNC, "("))
				{
					var a:Array = [];
					if (!match(TK_PUNC, ")"))
					{
						do
						{
							a.push(parseExpression());
						} while (match(TK_PUNC, ","));
						expect(TK_PUNC, ")");
					}
					node = {type: "Call", callee: node, args: a};
					continue;
				}
				break;
			}
			
			return node;
		}
		
		// =====================================================================
		// VM Runtime
		// =====================================================================
		
		private function runProgram(ast:Object):void
		{
			_envStack = [];
			_envStack.push(_env);
			
			_runningAst = ast;
			_isPaused = false;
			_steps = 0;
			
			_frames = [];
			_valueStack = [];
			
			_frames.push({type: "BlockFrame", stmts: ast.body, i: 0, inFunction: false});
			pump();
		}
		
		private function pump():void
		{
			if (_isPaused) return;
			
			while (_frames.length > 0)
			{
				step();
				
				var fr:Object = _frames[_frames.length - 1];
				
				switch (fr.type)
				{
				case "BlockFrame": 
					if (fr.i >= fr.stmts.length)
					{
						_frames.pop();
						continue;
					}
					
					_frames.push({type: "StmtFrame", node: fr.stmts[fr.i++], state: 0, inFunction: fr.inFunction});
					continue;
				
				case "StmtFrame": 
					tickStmtFrame(fr);
					if (_isPaused) return;
					continue;
				
				case "WhileFrame": 
					tickWhileFrame(fr);
					if (_isPaused) return;
					continue;
				
				case "CallUserFrame": 
					tickCallUserFrame(fr);
					if (_isPaused) return;
					continue;
				
				case "EvalFrame": 
					tickEvalFrame(fr);
					if (_isPaused) return;
					continue;
				
				default: 
					throw new Error("未知 frame 类型: " + fr.type);
				}
			}
			
			CheatPanel.log("代码执行器：脚本执行完成。");
			_runningAst = null;
		}
		
		private function step():void
		{
			if (++_steps > MAX_STEPS)
			{
				throw new Error("脚本步数超限（可能死循环）");
			}
		}
		
		// ---------------- Statement ticking ----------------
		
		private function tickStmtFrame(fr:Object):Boolean
		{
			var s:Object = fr.node;
			
			switch (s.type)
			{
			case "ImportDecl": 
				_frames.pop();
				return false;
			
			case "Block": 
				_frames.pop();
				_frames.push({type: "BlockFrame", stmts: s.body, i: 0, inFunction: fr.inFunction});
				return true;
			
			case "VarDecl": 
				if (fr.state == 0)
				{
					if (s.init != null)
					{
						fr.state = 1;
						fr.name = s.name;
						_frames.push({type: "EvalFrame", node: s.init, state: 0});
						return true;
					}
					envSet(s.name, undefined);
					_frames.pop();
					return false;
				}
				else
				{
					var vv:* = consumeValue(popValue(), true); // NEW: 只有真正赋值时才解析
					envSet(fr.name, vv);
					_frames.pop();
					return false;
				}
			
			case "Assign": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.left = s.left;
					fr.right = s.right;
					_frames.push({type: "EvalFrame", node: fr.right, state: 0});
					return true;
				}
				if (fr.state == 1)
				{
					fr.rval = consumeValue(popValue(), true); // NEW
					fr.state = 2;
					_frames.push({type: "EvalFrame", node: fr.left, state: 0});
					return true;
				}
				execAssign(fr.left, fr.rval);
				_frames.pop();
				return false;
			
			case "ExprStmt": 
				if (fr.state == 0)
				{
					fr.state = 1;
					_frames.push({type: "EvalFrame", node: s.expr, state: 0});
					return true;
				}
				popValue(); // discard
				_frames.pop();
				return false;
			
			case "If": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.test = s.test;
					fr.cons = s.cons;
					fr.alt = s.alt;
					_frames.push({type: "EvalFrame", node: fr.test, state: 0});
					return true;
				}
				var tv:* = consumeValue(popValue(), true); // NEW
				_frames.pop();
				_frames.push({type: "StmtFrame", node: truthy(tv) ? fr.cons : (fr.alt ? fr.alt : {type: "Block", body: []}), state: 0, inFunction: fr.inFunction});
				return true;
			
			case "While": 
				_frames.pop();
				_frames.push({type: "WhileFrame", node: s, state: 0, inFunction: fr.inFunction});
				return true;
			
			case "FunctionDecl": 
				var fnObj:Object = {type: "UserFunction", params: s.params, body: s.body, envSnapshot: _envStack.concat()};
				envSet(s.name, fnObj);
				_frames.pop();
				return false;
			
			case "Return": 
				if (!fr.inFunction)
				{
					if (fr.state == 0 && s.arg != null)
					{
						fr.state = 1;
						_frames.push({type: "EvalFrame", node: s.arg, state: 0});
						return true;
					}
					if (fr.state == 1) popValue();
					CheatPanel.log("代码执行器：顶层 return 被忽略。");
					_frames.length = 0;
					return false;
				}
				
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.hasArg = (s.arg != null);
					if (s.arg != null)
					{
						_frames.push({type: "EvalFrame", node: s.arg, state: 0});
						return true;
					}
					doReturnFromFunction(null);
					return false;
				}
				else
				{
					var rv:* = fr.hasArg ? consumeValue(popValue(), true) : null; // NEW
					doReturnFromFunction(rv);
					return false;
				}
			
			case "Break": 
				_frames.pop();
				handleBreakSignal();
				return false;
			
			case "Continue": 
				_frames.pop();
				handleContinueSignal();
				return false;
			
			default: 
				throw new Error("未知语句类型: " + s.type);
			}
		}
		
		private function tickWhileFrame(fr:Object):Boolean
		{
			var w:Object = fr.node;
			
			if (fr.state == 0)
			{
				fr.state = 1;
				_frames.push({type: "EvalFrame", node: w.test, state: 0});
				return true;
			}
			
			if (fr.state == 1)
			{
				var tv:* = consumeValue(popValue(), true); // NEW
				if (!truthy(tv))
				{
					_frames.pop();
					return false;
				}
				
				fr.state = 0;
				
				if (w.body.type == "Block")
				{
					_frames.push({type: "BlockFrame", stmts: w.body.body, i: 0, inFunction: fr.inFunction});
				}
				else
				{
					_frames.push({type: "BlockFrame", stmts: [w.body], i: 0, inFunction: fr.inFunction});
				}
				return true;
			}
			
			return true;
		}
		
		private function handleBreakSignal():void
		{
			while (_frames.length > 0)
			{
				var f:Object = _frames.pop();
				if (f.type == "WhileFrame")
				{
					return;
				}
			}
		}
		
		private function handleContinueSignal():void
		{
			while (_frames.length > 0)
			{
				var f:Object = _frames.pop();
				if (f.type == "WhileFrame")
				{
					_frames.push(f);
					return;
				}
			}
		}
		
		// ---------------- Function calling ----------------
		
		private function tickCallUserFrame(fr:Object):Boolean
		{
			if (fr.state == 0)
			{
				fr.state = 1;
				
				var localEnv:Dictionary = new Dictionary();
				var params:Array = fr.fn.params as Array;
				for (var i:int = 0; i < params.length; i++)
				{
					var pName:String = params[i];
					localEnv[pName] = (i < fr.args.length) ? fr.args[i] : undefined;
				}
				
				fr.savedStack = _envStack;
				_envStack = fr.fn.envSnapshot.concat();
				_envStack.push(localEnv);
				
				if (fr.fn.body.type == "Block")
				{
					_frames.push({type: "BlockFrame", stmts: fr.fn.body.body, i: 0, inFunction: true});
				}
				else
				{
					_frames.push({type: "BlockFrame", stmts: [fr.fn.body], i: 0, inFunction: true});
				}
				return true;
			}
			
			if (fr.state == 1)
			{
				_envStack = fr.savedStack;
				
				// body finished without return => null
				pushValue(null);
				
				_frames.pop();
				return false;
			}
			
			return true;
		}
		
		private function doReturnFromFunction(v:*):void
		{
			while (_frames.length > 0)
			{
				var f:Object = _frames[_frames.length - 1];
				
				if (f.type == "CallUserFrame")
				{
					_envStack = f.savedStack;
					pushValue(v);
					_frames.pop();
					return;
				}
				
				_frames.pop();
			}
		}
		
		// =====================================================================
		// Expression VM
		// =====================================================================
		
		private function tickEvalFrame(fr:Object):Boolean
		{
			var e:Object = fr.node;
			
			switch (e.type)
			{
			case "Literal": 
				_frames.pop();
				pushValue(e.value);
				return false;
			
			case "ArrayLiteral": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.arr = [];
					fr.idx = 0;
				}
				if (fr.idx < e.elements.length)
				{
					fr.state = 2;
					_frames.push({type: "EvalFrame", node: e.elements[fr.idx], state: 0});
					fr.idx++;
					return true;
				}
				_frames.pop();
				pushValue(fr.arr);
				return false;
			
			case "Unary": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.op = e.op;
					_frames.push({type: "EvalFrame", node: e.arg, state: 0});
					return true;
				}
				var av:* = consumeValue(popValue(), true); // NEW
				_frames.pop();
				pushValue((fr.op == "!") ? !truthy(av) : -Number(av));
				return false;
			
			case "Binary": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.op = e.op;
					fr.leftNode = e.left;
					fr.rightNode = e.right;
					_frames.push({type: "EvalFrame", node: fr.leftNode, state: 0});
					return true;
				}
				if (fr.state == 1)
				{
					fr.a = consumeValue(popValue(), true); // NEW
					fr.state = 2;
					_frames.push({type: "EvalFrame", node: fr.rightNode, state: 0});
					return true;
				}
				var b:* = consumeValue(popValue(), true); // NEW
				var a:* = fr.a;
				_frames.pop();
				pushValue(evalBinary(fr.op, a, b));
				return false;
			
			case "Name": 
				_frames.pop();
				pushValue(evalName(e.value));
				return false;
			
			case "Member": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.prop = e.prop;
					fr.objectNode = e.object;
					_frames.push({type: "EvalFrame", node: fr.objectNode, state: 0});
					return true;
				}
				var obj:* = popValue();
				
				// NEW: 包链占位符继续传递，不解析、不日志
				if (isPkgChain(obj))
				{
					_frames.pop();
					pushValue(makePkgChain(e));
					return false;
				}
				
				if (obj === null || obj === undefined)
				{
					// NEW: 如果看起来是包根开头，就把整个链变成占位符（不做半截反射）
					if (isChainStartsWithPackageRoot(e))
					{
						_frames.pop();
						pushValue(makePkgChain(e));
						return false;
					}
					_frames.pop();
					pushValue(null);
					return false;
				}
				
				_frames.pop();
				pushValue(obj[fr.prop]);
				return false;
			
			case "Index": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.objectNode = e.object;
					fr.indexNode = e.index;
					_frames.push({type: "EvalFrame", node: fr.objectNode, state: 0});
					return true;
				}
				if (fr.state == 1)
				{
					fr.base = popValue();
					fr.state = 2;
					_frames.push({type: "EvalFrame", node: fr.indexNode, state: 0});
					return true;
				}
				var idxVal:* = consumeValue(popValue(), true); // NEW（索引值也消费）
				var base:* = fr.base;
				
				// NEW: base 是占位符 => 整段 Index 继续占位
				if (isPkgChain(base))
				{
					_frames.pop();
					pushValue(makePkgChain(e));
					return false;
				}
				
				if (base === null || base === undefined)
				{
					if (isChainStartsWithPackageRoot(fr.objectNode))
					{
						_frames.pop();
						pushValue(makePkgChain(e));
						return false;
					}
					_frames.pop();
					pushValue(null);
					return false;
				}
				
				_frames.pop();
				pushValue(base[idxVal]);
				return false;
			
			case "New": 
				if (fr.state == 0)
				{
					fr.state = 1;
					fr.calleeNode = e.callee;
					fr.argsNodes = e.args;
					fr.argsVals = [];
					fr.argi = 0;
					_frames.push({type: "EvalFrame", node: fr.calleeNode, state: 0});
					return true;
				}
				if (fr.state == 1)
				{
					fr.ctor = consumeValue(popValue(), true); // NEW：ctor 也消费
					fr.state = 2;
				}
				if (fr.state == 2)
				{
					if (fr.argi < fr.argsNodes.length)
					{
						_frames.push({type: "EvalFrame", node: fr.argsNodes[fr.argi], state: 0});
						fr.argi++;
						fr.state = 3;
						return true;
					}
					_frames.pop();
					
					// NEW：最后构造前再确保 ctor 被解析
					fr.ctor = consumeValue(fr.ctor, true);
					
					// NEW：args 也全部消费一次
					for (var ni:int = 0; ni < fr.argsVals.length; ni++)
					{
						fr.argsVals[ni] = consumeValue(fr.argsVals[ni], true);
					}
					
					if (fr.ctor is Class)
					{
						pushValue(constructClass(fr.ctor as Class, fr.argsVals));
					}
					else
					{
						throw new Error("new 目标不是 Class");
					}
					return false;
				}
				if (fr.state == 3)
				{
					fr.argsVals.push(popValue()); // 先收集，统一在 state2 构造前 consume
					fr.state = 2;
					return true;
				}
				return true;
			
			case "Call": 
				return tickCallExpr(fr, e);
			
			default: 
				_frames.pop();
				pushValue(null);
				return false;
			}
		}
		
		private function tickCallExpr(fr:Object, e:Object):Boolean
		{
			if (fr.state == 0)
			{
				fr.state = 1;
				fr.calleeNode = e.callee;
				fr.argsNodes = e.args;
				fr.argsVals = [];
				fr.argi = 0;
				
				_frames.push({type: "EvalFrame", node: fr.calleeNode, state: 0});
				return true;
			}
			
			if (fr.state == 1)
			{
				fr.calleeVal = popValue();
				fr.state = 2;
			}
			
			if (fr.state == 2)
			{
				if (fr.argi < fr.argsNodes.length)
				{
					fr.state = 3;
					_frames.push({type: "EvalFrame", node: fr.argsNodes[fr.argi], state: 0});
					fr.argi++;
					return true;
				}
				fr.state = 4;
			}
			
			if (fr.state == 3)
			{
				fr.argsVals.push(popValue());
				fr.state = 2;
				return true;
			}
			
			if (fr.state == 4)
			{
				// NEW：callee/args 在真正调用前消费（此时失败才打日志）
				fr.calleeVal = consumeValue(fr.calleeVal, true);
				for (var ii:int = 0; ii < fr.argsVals.length; ii++)
				{
					fr.argsVals[ii] = consumeValue(fr.argsVals[ii], true);
				}
				
				var builtin:* = tryEvalBuiltinCallVM(e.callee, fr.argsVals);
				if (builtin !== BUILTIN_NOT_MATCHED)
				{
					_frames.pop();
					pushValue(builtin);
					return false;
				}
				
				if (e.callee.type == "Name")
				{
					var uv:* = envGet(e.callee.value);
					if (isUserFunction(uv))
					{
						_frames.pop();
						_frames.push({type: "CallUserFrame", fn: uv, args: fr.argsVals, state: 0});
						return true;
					}
				}
				
				_frames.pop();
				pushValue(evalCallByReflectionValues(e.callee, fr.argsVals));
				return false;
			}
			
			return true;
		}
		
		private function pushValue(v:*):void  { _valueStack.push(v); }
		
		private function popValue():*  { return _valueStack.pop(); }
		
		// =====================================================================
		// Env / helpers
		// =====================================================================
		
		private function envGet(name:String):*
		{
			var i:int = _envStack.length - 1;
			while (i >= 0)
			{
				var d:Dictionary = _envStack[i];
				if (d.hasOwnProperty(name)) return d[name];
				i--;
			}
			return undefined;
		}
		
		private function envSet(name:String, v:*):void
		{
			Dictionary(_envStack[_envStack.length - 1])[name] = v;
		}
		
		private function truthy(v:*):Boolean
		{
			return !(v === false || v === 0 || v == null || v === undefined);
		}
		
		private function isUserFunction(v:*):Boolean
		{
			return (v != null) && (v is Object) && Object(v).hasOwnProperty("type") && (Object(v)["type"] == "UserFunction");
		}
		
		private function evalName(name:String):*
		{
			// builtin 名称：返回一个占位符，真正执行在 Call 阶段
			if (_builtinNames.hasOwnProperty(name.toLowerCase()))
			{
				return name;
			}
			
			if (_importMap.hasOwnProperty(name))
			{
				return evalExpression2(_importMap[name], true);
			}
			
			var v:* = envGet(name);
			if (v !== undefined)
			{
				if (isUserFunction(v)) return wrapUserFunction(v);
				return v;
			}
			
			// NEW：包根名返回占位符（不再返回 undefined，避免半截反射 + 刷日志）
			if (isPackageRootName(name)) return makePkgChain({type: "Name", value: name});
			
			return evalByReflection({type: "Name", value: name});
		}
		
		private function wrapUserFunction(fnObj:Object):Function
		{
			if (fnObj != null && (fnObj is Object) && Object(fnObj).hasOwnProperty("__wrapped") && (Object(fnObj)["__wrapped"] is Function))
			{
				return Object(fnObj)["__wrapped"] as Function;
			}
			
			var self:CheatCodeExecutorControl = this;
			var f:Function = function(... args):*
			{
				self._frames.push({type: "CallUserFrame", fn: fnObj, args: args, state: 0});
				self.pump();
				return null;
			};
			
			try
			{
				Object(fnObj)["__wrapped"] = f;
			}
			catch (e:Error)
			{
			}
			return f;
		}
		
		private function execAssign(left:Object, rv:*):*
		{
			if (left.type == "Name")
			{
				envSet(left.value, rv);
				return rv;
			}
			
			if (left.type == "Member")
			{
				var obj:* = evalChainOrObject(left.object);
				if (obj == null) throw new Error("成员赋值对象为 null");
				obj[left.prop] = rv;
				return rv;
			}
			
			if (left.type == "Index")
			{
				var base:* = evalChainOrObject(left.object);
				if (base == null) throw new Error("索引赋值对象为 null");
				var idx:* = evalExprSync(left.index);
				base[idx] = rv;
				return rv;
			}
			
			throw new Error("赋值左侧必须是变量或成员链");
		}
		
		private function evalChainOrObject(node:Object):*
		{
			var v:* = evalExprSync(node);
			if (v === null || v === undefined)
			{
				if (isChainStartsWithPackageRoot(node))
				{
					return evalChainByReflection(node);
				}
			}
			return v;
		}
		
		private function evalExprSync(e:Object):*
		{
			switch (e.type)
			{
			case "Literal": 
				return e.value;
			
			case "Name": 
				// 保持惰性：可能返回 pkgChain，占位符不要在这里 consume
				return evalName(e.value);
			
			case "Member": 
				var o:* = evalExprSync(e.object);
				
				// 关键：占位符继续延伸，不解析
				if (isPkgChain(o)) return makePkgChain(e);
				
				// 非占位符才真正取值
				o = consumeValue(o, true);
				if (o == null) return null;
				return o[e.prop];
			
			case "Index": 
				var b:* = evalExprSync(e.object);
				
				if (isPkgChain(b)) return makePkgChain(e);
				
				b = consumeValue(b, true);
				if (b == null) return null;
				
				var k:* = evalExprSync(e.index);
				k = consumeValue(k, true);
				
				return b[k];
			
			case "Unary": 
				var av:* = consumeValue(evalExprSync(e.arg), true);
				return (e.op == "!") ? !truthy(av) : -Number(av);
			
			case "Binary": 
				return evalBinary(e.op, consumeValue(evalExprSync(e.left), true), consumeValue(evalExprSync(e.right), true));
			
			case "Call": 
				var args:Array = [];
				for each (var an:Object in e.args) args.push(evalExprSync(an)); // 先不 consume
				
				// callee 也先拿到（可能是 pkgChain）
				var calleeVal:* = evalExprSync(e.callee);
				calleeVal = consumeValue(calleeVal, true);
				
				for (var ai:int = 0; ai < args.length; ai++) args[ai] = consumeValue(args[ai], true);
				
				// 这里建议直接走 VM 那套 resolveCalleeValue（它会处理 Member 的 thisObj）
				return evalCallByReflectionValues(e.callee, args);
			
			case "New": 
				var ctor:* = evalExprSync(e.callee);
				ctor = consumeValue(ctor, true);
				
				var avs:Array = [];
				for each (var nn:Object in e.args) avs.push(consumeValue(evalExprSync(nn), true));
				
				if (ctor is Class) return constructClass(ctor as Class, avs);
				throw new Error("new 目标不是 Class");
			
			case "ArrayLiteral": 
				var arr:Array = [];
				for each (var el:Object in e.elements) arr.push(consumeValue(evalExprSync(el), true));
				return arr;
			
			default: 
				return null;
			}
		}
		
		private function evalBinary(op:String, a:*, b:*):*
		{
			switch (op)
			{
			case "+": 
				return a + b;
			case "-": 
				return Number(a) - Number(b);
			case "*": 
				return Number(a) * Number(b);
			case "/": 
				return Number(a) / Number(b);
			case "%": 
				return Number(a) % Number(b);
			case "==": 
				return a == b;
			case "!=": 
				return a != b;
			case "<": 
				return Number(a) < Number(b);
			case ">": 
				return Number(a) > Number(b);
			case "<=": 
				return Number(a) <= Number(b);
			case ">=": 
				return Number(a) >= Number(b);
			case "&&": 
				return truthy(a) && truthy(b);
			case "||": 
				return truthy(a) || truthy(b);
			default: 
				throw new Error("不支持的运算符: " + op);
			}
		}
		
		// =====================================================================
		// Builtins
		// =====================================================================
		
		private function tryEvalBuiltinCallVM(calleeNode:Object, argVals:Array):*
		{
			if (calleeNode.type != "Name") return BUILTIN_NOT_MATCHED;
			
			var lname:String = String(calleeNode.value).toLowerCase();
			if (lname == "delay") return evalBuiltinDelayVM(argVals);
			if (lname == "log") return evalBuiltinLogVM(argVals);
			if (lname == "click") return evalBuiltinClickVM(argVals);
			if (lname == "getcolor") return evalBuiltinGetColorVM(argVals);
			return BUILTIN_NOT_MATCHED;
		}
		
		private function evalBuiltinLogVM(argVals:Array):*
		{
			var parts:Array = [];
			for each (var v:* in argVals) parts.push(String(v));
			CheatPanel.log(parts.join(" "));
			return null;
		}
		
		private function evalBuiltinDelayVM(argVals:Array):*
		{
			if (argVals.length != 1) throw new Error("Delay(ms) 只接受1个参数");
			var ms:int = int(argVals[0]);
			
			_isPaused = true;
			
			var self:CheatCodeExecutorControl = this;
			setTimeout(function():void
			{
				self._isPaused = false;
				self.pump();
			}, ms);
			
			return null;
		}
		
		private function evalBuiltinClickVM(argVals:Array):*
		{
			if (argVals.length < 2 || argVals.length > 3) throw new Error("click(x, y, verbose=false) 只接受 2 或 3 个参数");
			var x:Number = Number(argVals[0]);
			var y:Number = Number(argVals[1]);
			var verbose:Boolean = (argVals.length == 3) ? truthy(argVals[2]) : false;
			clickAt(x, y, verbose);
			return null;
		}
		
		private function evalBuiltinGetColorVM(argVals:Array):*
		{
			if (argVals.length != 2) throw new Error("getColor(x, y) 只接受 2 个参数");
			return getColorAt(int(argVals[0]), int(argVals[1]));
		}
		
		// =====================================================================
		// click / getColor
		// =====================================================================
		
		private function getColorAt(stageX:int, stageY:int):uint
		{
			if (!stage)
			{
				CheatPanel.log("getColorAt 失败：stage 为 null");
				return 0;
			}
			try
			{
				if (stageX < 0 || stageY < 0 || stageX >= stage.stageWidth || stageY >= stage.stageHeight)
				{
					CheatPanel.log("getColorAt 越界: (" + stageX + "," + stageY + ")");
					return 0;
				}
				var bmd:BitmapData = new BitmapData(1, 1, true, 0);
				var m:Matrix = new Matrix();
				m.translate(-stageX, -stageY);
				bmd.draw(stage, m, null, null, new Rectangle(0, 0, 1, 1), true);
				var c:uint = bmd.getPixel32(0, 0);
				bmd.dispose();
				return c;
			}
			catch (err:Error)
			{
				CheatPanel.log("getColorAt 出错: " + err.message);
			}
			return 0;
		}
		
		private function clickAt(stageX:Number, stageY:Number, verbose:Boolean = false):void
		{
			if (!stage)
			{
				if (verbose) CheatPanel.log("clickAt 失败：stage 为 null，无法点击 (" + stageX + ", " + stageY + ")");
				return;
			}
			try
			{
				var globalPt:Point = new Point(stageX, stageY);
				var list:Array = stage.getObjectsUnderPoint(globalPt);
				var chosenIO:InteractiveObject = null;
				var chosenOriginal:DisplayObject = null;
				
				if (list && list.length > 0)
				{
					for (var i:int = list.length - 1; i >= 0; i--)
					{
						var target:DisplayObject = list[i];
						var originalTarget:DisplayObject = target;
						
						while (target && !(target is InteractiveObject))
						{
							target = target.parent;
						}
						var io:InteractiveObject = target as InteractiveObject;
						if (io)
						{
							chosenIO = io;
							chosenOriginal = originalTarget;
							break;
						}
					}
					if (chosenIO)
					{
						var localPt:Point = chosenIO.globalToLocal(globalPt);
						chosenIO.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN, true, false, localPt.x, localPt.y));
						chosenIO.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP, true, false, localPt.x, localPt.y));
						chosenIO.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false, localPt.x, localPt.y));
						if (verbose)
						{
							CheatPanel.log("clickAt 成功：已点击对象 [" + chosenIO.name + "] @ (" + stageX + ", " + stageY + ")，原始命中为 " + chosenOriginal.toString());
						}
						return;
					}
					if (verbose) CheatPanel.log("clickAt 提示：(" + stageX + ", " + stageY + ") 命中链上没有 InteractiveObject，改为点击 stage。");
				}
				else if (verbose)
				{
					CheatPanel.log("clickAt 提示：(" + stageX + ", " + stageY + ") 下没有任何显示对象，改为点击 stage。");
				}
				
				var stageLocal:Point = stage.globalToLocal(globalPt);
				stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN, true, false, stageLocal.x, stageLocal.y));
				stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP, true, false, stageLocal.x, stageLocal.y));
				stage.dispatchEvent(new MouseEvent(MouseEvent.CLICK, true, false, stageLocal.x, stageLocal.y));
				if (verbose) CheatPanel.log("clickAt 已向 stage 派发点击事件 @ (" + stageX + ", " + stageY + ")");
			}
			catch (err:Error)
			{
				if (verbose) CheatPanel.log("clickAt 调用出错：" + err.message);
			}
		}
		
		// =====================================================================
		// Reflection calling
		// =====================================================================
		
		private function evalCallByReflectionValues(calleeNode:Object, argVals:Array):*
		{
			var resolved:Object = resolveCalleeValue(calleeNode);
			var fn:Function = resolved.fn as Function;
			var thisObj:* = resolved.thisObj;
			
			if (fn == null) throw new Error("反射调用失败：callee 不是函数");
			return fn.apply(thisObj, argVals);
		}
		
		private function resolveCalleeValue(node:Object):Object
		{
			if (node.type == "Name")
			{
				if (_importMap.hasOwnProperty(node.value))
				{
					var imp:* = evalExpression2(_importMap[node.value], true);
					return {fn: imp, thisObj: null};
				}
				
				var v:* = envGet(node.value);
				if (v !== undefined)
				{
					if (isUserFunction(v)) return {fn: wrapUserFunction(v), thisObj: null};
					return {fn: v, thisObj: null};
				}
				
				var obj:* = evalByReflection(node);
				return {fn: obj, thisObj: null};
			}
			
			if (node.type == "Member")
			{
				var base:*;
				
				base = evalExprSync(node.object);
				base = consumeValue(base, true);
				
				if (base == null) return {fn: null, thisObj: null};
				var f:* = base[node.prop];
				return {fn: f, thisObj: base};
			}
			
			var vv:* = consumeValue(evalExprSync(node), true);
			return {fn: vv, thisObj: null};
		}
		
		private function evalByReflection(node:Object):*
		{
			var s:String = buildChainString(node);
			return evalExpression2(s, true);
		}
		
		private function evalChainByReflection(node:Object):*
		{
			var s:String = buildChainString(node);
			return evalExpression2(s, true);
		}
		
		private function buildChainString(node:Object):String
		{
			switch (node.type)
			{
			case "Name": 
				if (_importMap.hasOwnProperty(node.value)) return _importMap[node.value];
				return node.value;
			
			case "Index": 
				return buildChainString(node.object) + "[" + exprToString(node.index) + "]";
			
			case "Member": 
				return buildChainString(node.object) + "." + node.prop;
			
			case "Call": 
				var arr:Array = [];
				for each (var a:Object in node.args) arr.push(exprToString(a));
				return buildChainString(node.callee) + "(" + arr.join(",") + ")";
			
			default: 
				return "";
			}
		}
		
		private function exprToString(e:Object):String
		{
			switch (e.type)
			{
			case "Literal": 
				return literalToString(e.value);
			case "Name": 
			case "Member": 
			case "Call": 
				return buildChainString(e);
			case "Unary": 
				return e.op + exprToString(e.arg);
			case "Binary": 
				return exprToString(e.left) + e.op + exprToString(e.right);
			default: 
				return "";
			}
		}
		
		private function literalToString(v:*):String
		{
			if (v is String) return "\"" + v + "\"";
			switch (v)
			{
			case null: 
				return "null";
			case undefined: 
				return "undefined";
			default: 
				return String(v);
			}
		}
		
		private function isPackageRootName(name:String):Boolean
		{
			if (!/^[a-z_][a-z0-9_]*$/.test(name)) return false;
			
			if (_pkgRootCache.hasOwnProperty(name)) return Boolean(_pkgRootCache[name]);
			
			var ok:Boolean = true;
			try
			{
				if (ApplicationDomain.currentDomain.hasDefinition(name))
				{
					ok = false;
				}
			}
			catch (err:Error)
			{
			}
			
			_pkgRootCache[name] = ok;
			return ok;
		}
		
		private function isChainStartsWithPackageRoot(node:Object):Boolean
		{
			var root:String = getRootName(node);
			return root != null && isPackageRootName(root);
		}
		
		private function getRootName(node:Object):String
		{
			var cur:Object = node;
			while (cur && cur.type == "Member")
			{
				cur = cur.object;
			}
			if (cur && cur.type == "Name") return cur.value;
			return null;
		}
		
		// =====================================================================
		// Reflection evaluator (UPDATED: logOnFail switch)
		// =====================================================================
		
		private function evalExpression(expr:String):*
		{
			return evalExpression2(expr, true);
		}
		
		private function evalExpression2(expr:String, logOnFail:Boolean):*
		{
			expr = expr.replace(/\s+/g, "");
			if (expr == "")
			{
				if (logOnFail) CheatPanel.log("代码执行器：表达式为空。");
				return null;
			}
			
			var domain:ApplicationDomain = ApplicationDomain.currentDomain;
			var firstParen:int = expr.indexOf("(");
			var searchEnd:int = (firstParen >= 0) ? firstParen : expr.length;
			
			var key:String = expr.substring(0, searchEnd);
			var cached:Object = _classResolveCache[key];
			var className:String = null;
			var classEnd:int = 0;
			
			if (cached != null)
			{
				className = cached.className;
				classEnd = cached.classEnd;
			}
			else
			{
				var lastOkName:String = null;
				var lastOkEnd:int = 0;
				
				var i:int = 0;
				var p:int;
				var cand:String;
				
				while (true)
				{
					p = expr.indexOf(".", i);
					if (p < 0 || p >= searchEnd) break;
					
					cand = expr.substring(0, p);
					if (cand.length > 0 && domain.hasDefinition(cand))
					{
						lastOkName = cand;
						lastOkEnd = p;
					}
					i = p + 1;
				}
				
				if (searchEnd > 0)
				{
					cand = expr.substring(0, searchEnd);
					if (domain.hasDefinition(cand))
					{
						lastOkName = cand;
						lastOkEnd = searchEnd;
					}
				}
				
				className = lastOkName;
				classEnd = lastOkEnd;
				
				_classResolveCache[key] = {className: className, classEnd: classEnd};
			}
			
			if (!className)
			{
				if (logOnFail) CheatPanel.log("代码执行器：找不到类前缀，表达式必须以 Class 开头：" + expr);
				return null;
			}
			
			var cls:Class = _classCache[className] as Class;
			if (cls == null)
			{
				cls = domain.getDefinition(className) as Class;
				if (!cls)
				{
					if (logOnFail) CheatPanel.log("代码执行器：getDefinition 返回的不是 Class：" + className);
					return null;
				}
				_classCache[className] = cls;
			}
			
			var current:* = cls;
			var idx:int = classEnd;
			
			while (idx < expr.length)
			{
				var ch:String = expr.charAt(idx);
				if (ch != ".")
				{
					if (logOnFail) CheatPanel.log("代码执行器：语法错误，期望 '.'：" + expr);
					return current;
				}
				
				var start:int = ++idx;
				while (idx < expr.length)
				{
					ch = expr.charAt(idx);
					if (!((ch >= "0" && ch <= "9") || (ch >= "A" && ch <= "Z") || (ch >= "a" && ch <= "z") || ch == "_" || ch == "$"))
					{
						break;
					}
					idx++;
				}
				if (idx == start)
				{
					if (logOnFail) CheatPanel.log("代码执行器：缺少标识符：" + expr);
					return current;
				}
				
				var name:String = expr.substring(start, idx);
				
				if (idx < expr.length && expr.charAt(idx) == "(")
				{
					var startParen:int = idx;
					var depth:int = 0;
					var j:int = idx;
					while (j < expr.length)
					{
						ch = expr.charAt(j);
						if (ch == "(") depth++;
						else if (ch == ")")
						{
							if (--depth == 0) break;
						}
						j++;
					}
					if (depth != 0)
					{
						if (logOnFail) CheatPanel.log("代码执行器：括号不匹配：" + expr);
						return current;
					}
					
					var argsPart:String = expr.substring(startParen + 1, j);
					var args:Array = parseArgsExpression(argsPart);
					
					if (!(name in current) || !(current[name] is Function))
					{
						if (logOnFail) CheatPanel.log("代码执行器：找不到可调用方法：" + name);
						return null;
					}
					
					current = current[name].apply(current, args);
					idx = j + 1;
				}
				else
				{
					if (!(name in current))
					{
						if (logOnFail) CheatPanel.log("代码执行器：找不到成员：" + name);
						return null;
					}
					current = current[name];
				}
			}
			
			return current;
		}
		
		private function parseArgsExpression(argsPart:String):Array
		{
			var args:Array = [];
			var depth:int = 0;
			var inStr:Boolean = false;
			var quoteChar:String = "";
			var cur:String = "";
			
			argsPart = argsPart.replace(/^\s+|\s+$/g, "");
			if (argsPart == "") return args;
			
			var i:int = 0;
			while (i < argsPart.length)
			{
				var ch:String = argsPart.charAt(i);
				if (inStr)
				{
					cur += ch;
					if (ch == quoteChar) inStr = false;
				}
				else if (ch == "\"" || ch == "'")
				{
					inStr = true;
					quoteChar = ch;
					cur += ch;
				}
				else if (ch == "(")
				{
					depth++;
					cur += ch;
				}
				else if (ch == ")")
				{
					depth--;
					cur += ch;
				}
				else if (ch == "," && depth == 0)
				{
					args.push(parseSingleArg(cur));
					cur = "";
				}
				else
				{
					cur += ch;
				}
				i++;
			}
			
			if (cur.length > 0) args.push(parseSingleArg(cur));
			return args;
		}
		
		private function parseSingleArg(s:String):*
		{
			if (s == null) return null;
			s = s.replace(/^\s+|\s+$/g, "");
			if (s == "") return null;
			
			if (s == "true") return true;
			if (s == "false") return false;
			
			if ((s.charAt(0) == "\"" && s.charAt(s.length - 1) == "\"") || (s.charAt(0) == "'" && s.charAt(s.length - 1) == "'"))
			{
				return s.substring(1, s.length - 1);
			}
			
			if (/^-?\d+$/.test(s)) return int(s);
			if (/^-?\d+\.\d+$/.test(s)) return Number(s);
			
			if (s.indexOf(".") != -1 || s.indexOf("(") != -1)
			{
				return evalExpression2(s, true);
			}
			
			return s;
		}
		
		// =====================================================================
		// Constructor dispatcher (0~10 args)
		// =====================================================================
		
		private function constructClass(cls:Class, args:Array):*
		{
			var n:int = args ? args.length : 0;
			switch (n)
			{
			case 0: 
				return new cls();
			case 1: 
				return new cls(args[0]);
			case 2: 
				return new cls(args[0], args[1]);
			case 3: 
				return new cls(args[0], args[1], args[2]);
			case 4: 
				return new cls(args[0], args[1], args[2], args[3]);
			case 5: 
				return new cls(args[0], args[1], args[2], args[3], args[4]);
			case 6: 
				return new cls(args[0], args[1], args[2], args[3], args[4], args[5]);
			case 7: 
				return new cls(args[0], args[1], args[2], args[3], args[4], args[5], args[6]);
			case 8: 
				return new cls(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7]);
			case 9: 
				return new cls(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8]);
			case 10: 
				return new cls(args[0], args[1], args[2], args[3], args[4], args[5], args[6], args[7], args[8], args[9]);
			default: 
				throw new Error("new 参数过多（当前支持 0~10）");
			}
		}
	}
}
