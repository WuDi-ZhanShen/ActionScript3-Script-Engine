package
{
   import flash.display.BitmapData;
   import flash.display.DisplayObject;
   import flash.display.DisplayObjectContainer;
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
   import flash.utils.describeType;
   import flash.utils.getDefinitionByName;
   import flash.utils.getQualifiedClassName;
   import flash.utils.setTimeout;
   
   public class CheatCodeExecutorControl extends Sprite
   {
      
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
      
      private static const SIG_BREAK_OBJ:Object = {"sig":SIG_BREAK};
      
      private static const SIG_CONTINUE_OBJ:Object = {"sig":SIG_CONTINUE};
      
      private static const PKGCHAIN_TAG:String = "__pkgChain__";
      
      private const _builtinNames:Object = {
         "delay":true,
         "log":true,
         "click":true,
         "getcolor":true,
         "findwidget":true
      };
      
      private var _so:SharedObject;
      
      private var _loadBtn:Sprite;
      
      private var _loadBtnLabel:TextField;
      
      private var _fileRef:FileReference;
      
      private var _saveBtn:Sprite;
      
      private var _saveBtnLabel:TextField;
      
      private var _input:TextField;
      
      private var _btn:Sprite;
      
      private var _btnLabel:TextField;
      
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
      
      private var _importMap:Object = {};
      
      private var _importValueMap:Object = {};
      
      private var _classCache:Object = {};
      
      private var _classResolveCache:Object = {};
      
      private var _pkgChainRegistry:Dictionary = new Dictionary(true);
      
      private var _knownDomains:Array = [];
      
      private var _currentExecContext:String = "";
      
      private var _lastExecContext:String = "";
      
      public function CheatCodeExecutorControl()
      {
         super();
         buildUI();
         loadScriptFromSOL();
      }
      
      private function makePkgChain(node:Object) : Object
      {
         var o:Object = {};
         o[PKGCHAIN_TAG] = true;
         o.node = node;
         _pkgChainRegistry[o] = true;
         return o;
      }
      
      private function isPkgChain(v:*) : Boolean
      {
         if(v === null || v === undefined)
         {
            return false;
         }
         try
         {
            return _pkgChainRegistry[v] === true;
         }
         catch(err:Error)
         {
         }
         return false;
      }
      
      private function safeHasOwnProperty(value:*, name:String) : Boolean
      {
         if(value === null || value === undefined)
         {
            return false;
         }
         try
         {
            return Object(value).hasOwnProperty(name);
         }
         catch(err:Error)
         {
         }
         return false;
      }
      
      private function consumeValue(v:*, logOnFail:Boolean) : *
      {
         if(!isPkgChain(v))
         {
            return v;
         }
         var node:Object = Object(v).node;
         var expr:String = buildChainString(node);
         return evalExpression2(expr,logOnFail);
      }
      
      private function buildUI() : void
      {
         _input = new TextField();
         _input.type = TextFieldType.INPUT;
         _input.border = true;
         _input.background = true;
         _input.backgroundColor = 2763306;
         var tfInput:TextFormat = new TextFormat("宋体",12,16777215);
         _input.defaultTextFormat = tfInput;
         _input.width = CheatPanel.public::PANEL_WIDTH - 40;
         _input.height = 160;
         _input.multiline = true;
         _input.wordWrap = true;
         _input.x = 20;
         _input.y = 0;
         _input.text = "var x=1;\nwhile(x<=4){\n  if(x==2){ x=x+1; continue; }\n  log(\"Hello\"+x);\n  Delay(1000);\n  x=x+1;\n}\n";
         addChild(_input);
         _btn = new Sprite();
         _btn.graphics.beginFill(4473924,1);
         _btn.graphics.drawRoundRect(0,0,40,22,8,8);
         _btn.graphics.endFill();
         _btn.buttonMode = true;
         _btn.mouseChildren = false;
         _btn.x = _input.x;
         _btn.y = _input.y + _input.height + 4;
         addChild(_btn);
         _btnLabel = new TextField();
         var tfBtn:TextFormat = new TextFormat("宋体",12,16777215,true);
         tfBtn.align = "center";
         _btnLabel.defaultTextFormat = tfBtn;
         _btnLabel.width = 40;
         _btnLabel.height = 20;
         _btnLabel.x = 0;
         _btnLabel.y = 1;
         _btnLabel.selectable = false;
         _btnLabel.text = "执行";
         _btn.addChild(_btnLabel);
         _btn.addEventListener(MouseEvent.CLICK,onExecuteClick);
         _saveBtn = new Sprite();
         _saveBtn.graphics.beginFill(4473924,1);
         _saveBtn.graphics.drawRoundRect(0,0,40,22,8,8);
         _saveBtn.graphics.endFill();
         _saveBtn.buttonMode = true;
         _saveBtn.mouseChildren = false;
         _saveBtn.x = _btn.x + _btn.width + 6;
         _saveBtn.y = _btn.y;
         addChild(_saveBtn);
         _saveBtnLabel = new TextField();
         var tfSave:TextFormat = new TextFormat("宋体",12,16777215,true);
         tfSave.align = "center";
         _saveBtnLabel.defaultTextFormat = tfSave;
         _saveBtnLabel.width = 40;
         _saveBtnLabel.height = 20;
         _saveBtnLabel.x = 0;
         _saveBtnLabel.y = 1;
         _saveBtnLabel.selectable = false;
         _saveBtnLabel.text = "保存";
         _saveBtn.addChild(_saveBtnLabel);
         _saveBtn.addEventListener(MouseEvent.CLICK,onSaveClick);
         _input.addEventListener(FocusEvent.FOCUS_IN,onInputFocusIn);
         _input.addEventListener(FocusEvent.FOCUS_OUT,onInputFocusOut);
         _loadBtn = new Sprite();
         _loadBtn.graphics.beginFill(4473924,1);
         _loadBtn.graphics.drawRoundRect(0,0,85,22,8,8);
         _loadBtn.graphics.endFill();
         _loadBtn.buttonMode = true;
         _loadBtn.mouseChildren = false;
         _loadBtn.x = _saveBtn.x + _saveBtn.width + 6;
         _loadBtn.y = _btn.y;
         addChild(_loadBtn);
         _loadBtnLabel = new TextField();
         var tfLoad:TextFormat = new TextFormat("宋体",12,16777215,true);
         tfLoad.align = "center";
         _loadBtnLabel.defaultTextFormat = tfLoad;
         _loadBtnLabel.width = 85;
         _loadBtnLabel.height = 20;
         _loadBtnLabel.x = 0;
         _loadBtnLabel.y = 1;
         _loadBtnLabel.selectable = false;
         _loadBtnLabel.text = "读本地脚本";
         _loadBtn.addChild(_loadBtnLabel);
         _loadBtn.addEventListener(MouseEvent.CLICK,onLoadClick);
      }
      
      private function onLoadClick(e:MouseEvent) : void
      {
         _fileRef = new FileReference();
         _fileRef.addEventListener(Event.SELECT,onFileSelected);
         _fileRef.addEventListener(Event.CANCEL,onFileCancel);
         var filters:Array = [new FileFilter("Text Files (*.txt)","*.txt")];
         _fileRef.browse(filters);
      }
      
      private function onFileSelected(e:Event) : void
      {
         _fileRef.removeEventListener(Event.SELECT,onFileSelected);
         _fileRef.removeEventListener(Event.CANCEL,onFileCancel);
         _fileRef.addEventListener(Event.COMPLETE,onFileLoaded);
         _fileRef.addEventListener(IOErrorEvent.IO_ERROR,onFileLoadError);
         try
         {
            _fileRef.load();
         }
         catch(err:Error)
         {
            CheatPanel.public::log("代码执行器：读取文件失败：" + err.message);
            cleanupFileRef();
         }
      }
      
      private function onFileLoaded(e:Event) : void
      {
         var data:String = "";
         try
         {
            data = _fileRef.data.toString();
         }
         catch(err:Error)
         {
            CheatPanel.public::log("代码执行器：文件内容解析失败：" + err.message);
            cleanupFileRef();
            return;
         }
         if(data != null)
         {
            data = data.replace(/[\r\n]/g,"\n");
            _input.text = data;
            CheatPanel.public::log("代码执行器：脚本已从本地加载。");
         }
         cleanupFileRef();
      }
      
      private function onFileLoadError(e:IOErrorEvent) : void
      {
         CheatPanel.public::log("代码执行器：读取文件 IO 错误：" + e.text);
         cleanupFileRef();
      }
      
      private function onFileCancel(e:Event) : void
      {
         cleanupFileRef();
      }
      
      private function cleanupFileRef() : void
      {
         if(!_fileRef)
         {
            return;
         }
         _fileRef.removeEventListener(Event.COMPLETE,onFileLoaded);
         _fileRef.removeEventListener(IOErrorEvent.IO_ERROR,onFileLoadError);
         _fileRef = null;
      }
      
      private function onInputFocusIn(e:FocusEvent) : void
      {
         if(stage)
         {
            stage.addEventListener(KeyboardEvent.KEY_DOWN,blockKeyEvent,true);
            stage.addEventListener(KeyboardEvent.KEY_UP,blockKeyEvent,true);
         }
      }
      
      private function onInputFocusOut(e:FocusEvent) : void
      {
         if(stage)
         {
            stage.removeEventListener(KeyboardEvent.KEY_DOWN,blockKeyEvent,true);
            stage.removeEventListener(KeyboardEvent.KEY_UP,blockKeyEvent,true);
         }
      }
      
      private function blockKeyEvent(e:KeyboardEvent) : void
      {
         if(stage && stage.focus == _input)
         {
            e.stopImmediatePropagation();
         }
      }
      
      private function onSaveClick(e:MouseEvent) : void
      {
         saveScriptToSOL();
         CheatPanel.public::log("代码执行器：脚本已保存。");
      }
      
      private function loadScriptFromSOL() : void
      {
         var saved:String;
         try
         {
            _so = SharedObject.getLocal(SOL_NAME);
            if(_so.data.hasOwnProperty(SOL_KEY_SCRIPT))
            {
               saved = String(_so.data[SOL_KEY_SCRIPT]);
               if(saved && saved.replace(/\s+/g,"") != "")
               {
                  _input.text = saved;
               }
            }
         }
         catch(err:Error)
         {
         }
      }
      
      private function saveScriptToSOL() : void
      {
         try
         {
            if(!_so)
            {
               _so = SharedObject.getLocal(SOL_NAME);
            }
            _so.data[SOL_KEY_SCRIPT] = _input.text;
            _so.flush();
         }
         catch(err:Error)
         {
         }
      }
      
      override public function get height() : Number
      {
         return _btn.y + _btn.height;
      }
      
      private function onExecuteClick(e:MouseEvent) : void
      {
         var cmd:String = _input.text;
         if(!cmd || cmd.replace(/\s+/g,"") == "")
         {
            CheatPanel.public::log("代码执行器：输入为空。");
            return;
         }
         try
         {
            executeCommand(cmd);
         }
         catch(err:Error)
         {
            reportExecutionError(err);
         }
      }
      
      private function reportExecutionError(err:Error) : void
      {
         var stack:String;
         var detail:String = "代码执行器：执行过程中异常：\n" + err.name + ": " + err.message;
         var context:String = getExecutionContext();
         if(context.length > 0)
         {
            detail += "\n执行位置：" + context;
         }
         stack = err.getStackTrace();
         if(stack != null && stack.length > 0)
         {
            detail += "\n" + stack;
         }
         try
         {
            CheatPanel.public::log(detail);
         }
         catch(logErr:Error)
         {
         }
      }
      
      private function executeCommand(cmd:String) : void
      {
         cmd = cmd.replace(/[\r\n]/g,"\n");
         _steps = 0;
         _isPaused = false;
         _env = new Dictionary();
         _importMap = {};
         _importValueMap = {};
         _classCache = {};
         _classResolveCache = {};
         _pkgChainRegistry = new Dictionary(true);
         _currentExecContext = "";
         _lastExecContext = "";
         refreshKnownDomains();
         var tokens:Array = tokenize(cmd);
         var ast:Object = parseProgram(tokens);
         runProgram(ast);
      }
      
      private function setExecutionContext(value:String) : void
      {
         _currentExecContext = value == null ? "" : value;
         if(_currentExecContext.length > 0)
         {
            _lastExecContext = _currentExecContext;
         }
      }
      
      private function getExecutionContext() : String
      {
         if(_currentExecContext != null && _currentExecContext.length > 0)
         {
            return _currentExecContext;
         }
         return _lastExecContext == null ? "" : _lastExecContext;
      }
      
      private function safeNodeType(node:*) : String
      {
         if(node === null || node === undefined)
         {
            return "<null>";
         }
         try
         {
            return String(node["type"]);
         }
         catch(err:Error)
         {
         }
         return "<未知>";
      }
      
      private function safeExprText(node:Object) : String
      {
         if(node === null || node === undefined)
         {
            return "";
         }
         try
         {
            return exprToString(node);
         }
         catch(err:Error)
         {
         }
         try
         {
            return buildChainString(node);
         }
         catch(err2:Error)
         {
         }
         return "<" + safeNodeType(node) + ">";
      }
      
      private function statementText(node:Object) : String
      {
         var nodeType:String;
         if(node === null || node === undefined)
         {
            return "";
         }
         nodeType = safeNodeType(node);
         try
         {
            switch(nodeType)
            {
               case "VarDecl":
                  return "var " + String(node["name"]) + (node["init"] != null ? " = " + safeExprText(node["init"]) : "");
               case "Assign":
                  return safeExprText(node["left"]) + " = " + safeExprText(node["right"]);
               case "ExprStmt":
                  return safeExprText(node["expr"]);
               case "If":
                  return "if (" + safeExprText(node["test"]) + ")";
               case "While":
                  return "while (" + safeExprText(node["test"]) + ")";
               case "FunctionDecl":
                  return "function " + String(node["name"]) + "(...)";
               case "Return":
                  return "return " + (node["arg"] != null ? safeExprText(node["arg"]) : "");
               default:
                  return nodeType;
            }
         }
         catch(err:Error)
         {
            return "<" + nodeType + "，诊断文本生成失败:" + err.name + ">";
         }
      }
      
      private function tokenize(src:String) : Array
      {
         var tokens:Array = [];
         var i:int = 0;
         while(i < src.length)
         {
            var ch:String = src.charAt(i);
            if(ch <= " ")
            {
               i++;
            }
            else if(i + 1 < src.length && src.charAt(i) == "/" && src.charAt(i + 1) == "/")
            {
               i += 2;
               while(i < src.length)
               {
                  ch = src.charAt(i);
                  if(ch == "\n" || ch == "\r")
                  {
                     break;
                  }
                  i++;
               }
            }
            else if(ch >= "0" && ch <= "9" || ch == "." && i + 1 < src.length && src.charAt(i + 1) >= "0" && src.charAt(i + 1) <= "9")
            {
               if(ch == "0" && i + 1 < src.length && (src.charAt(i + 1) == "x" || src.charAt(i + 1) == "X"))
               {
                  var j:int = i + 2;
                  while(j < src.length)
                  {
                     var cj:String = src.charAt(j);
                     if(!(cj >= "0" && cj <= "9" || cj >= "a" && cj <= "f" || cj >= "A" && cj <= "F"))
                     {
                        break;
                     }
                     j++;
                  }
               }
               else
               {
                  j = i;
                  var sawDot:Boolean = false;
                  var sawExp:Boolean = false;
                  while(j < src.length)
                  {
                     cj = src.charAt(j);
                     if(cj >= "0" && cj <= "9")
                     {
                        j++;
                     }
                     else if(cj == "." && !sawDot && !sawExp)
                     {
                        sawDot = true;
                        j++;
                     }
                     else
                     {
                        if(!((cj == "e" || cj == "E") && !sawExp))
                        {
                           break;
                        }
                        sawExp = true;
                        if(++j < src.length && (src.charAt(j) == "+" || src.charAt(j) == "-"))
                        {
                           j++;
                        }
                     }
                  }
               }
               tokens.push({
                  "type":TK_NUM,
                  "value":src.substring(i,j)
               });
               i = j;
            }
            else if(isIdentStart(src.charCodeAt(i)))
            {
               j = i + 1;
               while(j < src.length && isIdentPart(src.charCodeAt(j)))
               {
                  j++;
               }
               var word:String = src.substring(i,j);
               var kw:Boolean = word == "var" || word == "if" || word == "else" || word == "while" || word == "true" || word == "false" || word == "null" || word == "undefined" || word == "function" || word == "return" || word == "break" || word == "continue" || word == "import" || word == "as" || word == "new";
               tokens.push({
                  "type":(kw ? TK_KW : TK_ID),
                  "value":word
               });
               i = j;
            }
            else if(ch == "\"" || ch == "\'")
            {
               var quote:String = ch;
               j = i + 1;
               var buf:String = "";
               while(j < src.length)
               {
                  ch = src.charAt(j);
                  if(ch == "\\")
                  {
                     if(j + 1 < src.length)
                     {
                        var escapedChar:String = src.charAt(j + 1);
                        if(escapedChar == "n")
                        {
                           buf += "\n";
                        }
                        else if(escapedChar == "r")
                        {
                           buf += "\r";
                        }
                        else if(escapedChar == "t")
                        {
                           buf += "\t";
                        }
                        else
                        {
                           buf += escapedChar;
                        }
                        j += 2;
                        continue;
                     }
                  }
                  if(ch == quote)
                  {
                     break;
                  }
                  buf += ch;
                  j++;
               }
               tokens.push({
                  "type":TK_STR,
                  "value":buf
               });
               i = j + 1;
            }
            else
            {
               var two:String = i + 1 < src.length ? src.substr(i,2) : "";
               if(two == "==" || two == "!=" || two == "<=" || two == ">=" || two == "&&" || two == "||")
               {
                  tokens.push({
                     "type":TK_OP,
                     "value":two
                  });
                  i += 2;
               }
               else if("+-*/%=<>!".indexOf(ch) >= 0)
               {
                  tokens.push({
                     "type":TK_OP,
                     "value":ch
                  });
                  i++;
               }
               else if("(){};,.[]:".indexOf(ch) >= 0)
               {
                  tokens.push({
                     "type":TK_PUNC,
                     "value":ch
                  });
                  i++;
               }
               else
               {
                  CheatPanel.public::log("Tokenizer: 非法字符: " + ch);
                  i++;
               }
            }
         }
         tokens.push({
            "type":TK_EOF,
            "value":""
         });
         return tokens;
      }
      
      private function isIdentStart(cc:int) : Boolean
      {
         if(cc >= 65 && cc <= 90 || cc >= 97 && cc <= 122 || cc == 95 || cc == 36)
         {
            return true;
         }
         if(cc >= 19968 && cc <= 40959)
         {
            return true;
         }
         if(cc >= 128)
         {
            if(cc == 12288)
            {
               return false;
            }
            return true;
         }
         return false;
      }
      
      private function isIdentPart(cc:int) : Boolean
      {
         if(isIdentStart(cc))
         {
            return true;
         }
         if(cc >= 48 && cc <= 57)
         {
            return true;
         }
         return false;
      }
      
      private function peek() : Object
      {
         return _toks[_pos];
      }
      
      private function nextTok() : Object
      {
         return _toks[_pos++];
      }
      
      private function match(type:String, value:String = null) : Boolean
      {
         var t:Object = peek();
         if(t.type != type)
         {
            return false;
         }
         if(value != null && t.value != value)
         {
            return false;
         }
         ++_pos;
         return true;
      }
      
      private function expect(type:String, value:String = null) : Object
      {
         var t:Object = peek();
         if(!match(type,value))
         {
            throw new Error("Parse error: expect " + type + " " + value + " but got " + t.type + " " + t.value);
         }
         return t;
      }
      
      private function parseProgram(tokens:Array) : Object
      {
         _toks = tokens;
         _pos = 0;
         var body:Array = [];
         while(peek().type != TK_EOF)
         {
            body.push(parseStatement());
         }
         return {
            "type":"Program",
            "body":body
         };
      }
      
      private function parseStatement() : Object
      {
         var t:Object = peek();
         if(t.type == TK_KW && t.value == "import")
         {
            nextTok();
            var parts:Array = [];
            var first:Object = expect(TK_ID);
            parts.push(first.value);
            while(match(TK_PUNC,"."))
            {
               var seg:Object = expect(TK_ID);
               parts.push(seg.value);
            }
            var alias:String = parts[parts.length - 1];
            if(peek().type == TK_KW && peek().value == "as")
            {
               nextTok();
               alias = expect(TK_ID).value;
            }
            expect(TK_PUNC,";");
            var importClassName:String = parts.join(".");
            _importMap[alias] = importClassName;
            return {"type":"ImportDecl"};
         }
         if(match(TK_PUNC,"{"))
         {
            var stmts:Array = [];
            while(!match(TK_PUNC,"}"))
            {
               stmts.push(parseStatement());
            }
            return {
               "type":"Block",
               "body":stmts
            };
         }
         if(t.type == TK_KW && t.value == "var")
         {
            nextTok();
            var idTok:Object = expect(TK_ID);
            var init:Object = null;
            if(match(TK_OP,"="))
            {
               init = parseExpression();
            }
            expect(TK_PUNC,";");
            return {
               "type":"VarDecl",
               "name":idTok.value,
               "init":init
            };
         }
         if(t.type == TK_KW && t.value == "if")
         {
            nextTok();
            expect(TK_PUNC,"(");
            var test:Object = parseExpression();
            expect(TK_PUNC,")");
            var cons:Object = parseStatement();
            var alt:Object = null;
            if(peek().type == TK_KW && peek().value == "else")
            {
               nextTok();
               alt = parseStatement();
            }
            return {
               "type":"If",
               "test":test,
               "cons":cons,
               "alt":alt
            };
         }
         if(t.type == TK_KW && t.value == "while")
         {
            nextTok();
            expect(TK_PUNC,"(");
            test = parseExpression();
            expect(TK_PUNC,")");
            var body:Object = parseStatement();
            return {
               "type":"While",
               "test":test,
               "body":body
            };
         }
         if(t.type == TK_KW && t.value == "function")
         {
            nextTok();
            var fnNameTok:Object = expect(TK_ID);
            expect(TK_PUNC,"(");
            var params:Array = [];
            if(!match(TK_PUNC,")"))
            {
               do
               {
                  var pTok:Object = expect(TK_ID);
                  params.push(pTok.value);
               }
               while(match(TK_PUNC,","));
               expect(TK_PUNC,")");
            }
            var fnBody:Object = parseStatement();
            return {
               "type":"FunctionDecl",
               "name":fnNameTok.value,
               "params":params,
               "body":fnBody
            };
         }
         if(t.type == TK_KW && t.value == "return")
         {
            nextTok();
            var arg:Object = null;
            if(!match(TK_PUNC,";"))
            {
               arg = parseExpression();
               expect(TK_PUNC,";");
            }
            return {
               "type":"Return",
               "arg":arg
            };
         }
         if(t.type == TK_KW && t.value == "break")
         {
            nextTok();
            expect(TK_PUNC,";");
            return {"type":"Break"};
         }
         if(t.type == TK_KW && t.value == "continue")
         {
            nextTok();
            expect(TK_PUNC,";");
            return {"type":"Continue"};
         }
         var expr:Object = parseExpression();
         if(match(TK_OP,"="))
         {
            var right:Object = parseExpression();
            expect(TK_PUNC,";");
            return {
               "type":"Assign",
               "left":expr,
               "right":right
            };
         }
         expect(TK_PUNC,";");
         return {
            "type":"ExprStmt",
            "expr":expr
         };
      }
      
      private function prec(op:String) : int
      {
         switch(op)
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
      
      private function parseExpression(minPrec:int = 1) : Object
      {
         var left:Object = parseUnary();
         while(peek().type == TK_OP && prec(peek().value) >= minPrec)
         {
            var opTok:Object = nextTok();
            var op:String = opTok.value;
            var right:Object = parseExpression(prec(op) + 1);
            left = {
               "type":"Binary",
               "op":op,
               "left":left,
               "right":right
            };
         }
         return left;
      }
      
      private function parseUnary() : Object
      {
         if(peek().type == TK_OP && (peek().value == "!" || peek().value == "-"))
         {
            var op:String = nextTok().value;
            var arg:Object = parseUnary();
            return {
               "type":"Unary",
               "op":op,
               "arg":arg
            };
         }
         return parsePrimary();
      }
      
      private function parsePrimary() : Object
      {
         var t:Object = peek();
         if(t.type == TK_KW && t.value == "new")
         {
            nextTok();
            var idTok:Object = expect(TK_ID);
            var target:Object = {
               "type":"Name",
               "value":idTok.value
            };
            while(true)
            {
               if(match(TK_PUNC,"."))
               {
                  var propTok:Object = expect(TK_ID);
                  target = {
                     "type":"Member",
                     "object":target,
                     "prop":propTok.value
                  };
               }
               else
               {
                  if(!match(TK_PUNC,"["))
                  {
                     break;
                  }
                  var indexExpr:Object = parseExpression();
                  expect(TK_PUNC,"]");
                  target = {
                     "type":"Index",
                     "object":target,
                     "index":indexExpr
                  };
               }
            }
            var args:Array = [];
            if(match(TK_PUNC,"("))
            {
               if(!match(TK_PUNC,")"))
               {
                  do
                  {
                     args.push(parseExpression());
                  }
                  while(match(TK_PUNC,","));
                  expect(TK_PUNC,")");
               }
            }
            var node:Object = {
               "type":"New",
               "callee":target,
               "args":args
            };
            return parsePostfix(node);
         }
         if(match(TK_NUM))
         {
            var numberText:String = String(t.value);
            node = {
               "type":"Literal",
               "value":(numberText.length > 2 && numberText.charAt(0) == "0" && (numberText.charAt(1) == "x" || numberText.charAt(1) == "X") ? parseInt(numberText.substr(2),16) : Number(numberText))
            };
            return parsePostfix(node);
         }
         if(match(TK_STR))
         {
            node = {
               "type":"Literal",
               "value":String(t.value)
            };
            return parsePostfix(node);
         }
         if(t.type == TK_KW && (t.value == "true" || t.value == "false" || t.value == "null" || t.value == "undefined"))
         {
            nextTok();
            if(t.value == "true")
            {
               var v:* = true;
            }
            else if(t.value == "false")
            {
               v = false;
            }
            else if(t.value == "undefined")
            {
               v = undefined;
            }
            else
            {
               v = null;
            }
            node = {
               "type":"Literal",
               "value":v
            };
            return parsePostfix(node);
         }
         if(match(TK_PUNC,"("))
         {
            node = parseExpression();
            expect(TK_PUNC,")");
            return parsePostfix(node);
         }
         if(match(TK_PUNC,"["))
         {
            var elements:Array = [];
            if(!match(TK_PUNC,"]"))
            {
               do
               {
                  elements.push(parseExpression());
               }
               while(match(TK_PUNC,","));
               expect(TK_PUNC,"]");
            }
            node = {
               "type":"ArrayLiteral",
               "elements":elements
            };
            return parsePostfix(node);
         }
         var nameTok:Object = expect(TK_ID);
         node = {
            "type":"Name",
            "value":nameTok.value
         };
         return parsePostfix(node);
      }
      
      private function parsePostfix(node:Object) : Object
      {
         while(true)
         {
            if(match(TK_PUNC,"."))
            {
               var pt:Object = expect(TK_ID);
               node = {
                  "type":"Member",
                  "object":node,
                  "prop":pt.value
               };
            }
            else if(match(TK_PUNC,"["))
            {
               var ie:Object = parseExpression();
               expect(TK_PUNC,"]");
               node = {
                  "type":"Index",
                  "object":node,
                  "index":ie
               };
            }
            else
            {
               if(!match(TK_PUNC,"("))
               {
                  break;
               }
               var a:Array = [];
               if(!match(TK_PUNC,")"))
               {
                  do
                  {
                     a.push(parseExpression());
                  }
                  while(match(TK_PUNC,","));
                  expect(TK_PUNC,")");
               }
               node = {
                  "type":"Call",
                  "callee":node,
                  "args":a
               };
            }
         }
         return node;
      }
      
      private function runProgram(ast:Object) : void
      {
         _envStack = [];
         _envStack.push(_env);
         _runningAst = ast;
         _isPaused = false;
         _steps = 0;
         _frames = [];
         _valueStack = [];
         _frames.push({
            "type":"BlockFrame",
            "stmts":ast.body,
            "i":0,
            "inFunction":false
         });
         pump();
      }
      
      private function pump() : void
      {
         if(_isPaused)
         {
            return;
         }
         while(_frames.length > 0)
         {
            processTopFrameOnce();
            if(_isPaused)
            {
               return;
            }
         }
         CheatPanel.public::log("代码执行器：脚本执行完成。");
         _runningAst = null;
      }
      
      private function processTopFrameOnce() : void
      {
         if(_frames.length == 0)
         {
            return;
         }
         step();
         var fr:Object = _frames[_frames.length - 1];
         if(fr === null || fr === undefined)
         {
            throw new Error("顶部执行帧为空");
         }
         var frameType:String = String(fr["type"]);
         switch(frameType)
         {
            case "BlockFrame":
               var stmts:Array = fr["stmts"] as Array;
               var blockIndex:int = int(fr["i"]);
               if(stmts == null)
               {
                  throw new Error("BlockFrame.stmts 不是数组");
               }
               if(blockIndex >= stmts.length)
               {
                  _frames.pop();
                  break;
               }
               var nextStmt:Object = stmts[blockIndex];
               fr["i"] = blockIndex + 1;
               setExecutionContext("语句：" + statementText(nextStmt));
               _frames.push({
                  "type":"StmtFrame",
                  "node":nextStmt,
                  "state":0,
                  "inFunction":Boolean(fr["inFunction"])
               });
               break;
            case "StmtFrame":
               setExecutionContext("语句：" + statementText(fr["node"]));
               tickStmtFrame(fr);
               break;
            case "WhileFrame":
               setExecutionContext("while：" + safeExprText(fr["node"] != null ? fr["node"]["test"] : null));
               tickWhileFrame(fr);
               break;
            case "CallUserFrame":
               setExecutionContext("脚本函数调用");
               tickCallUserFrame(fr);
               break;
            case "EvalFrame":
               setExecutionContext("表达式：" + safeExprText(fr["node"]));
               tickEvalFrame(fr);
               break;
            default:
               throw new Error("未知 frame 类型: " + frameType);
         }
      }
      
      private function step() : void
      {
         if(++_steps > MAX_STEPS)
         {
            throw new Error("脚本步数超限（可能死循环）");
         }
      }
      
      private function tickStmtFrame(fr:Object) : Boolean
      {
         var s:Object = fr["node"];
         setExecutionContext("语句：" + statementText(s));
         switch(s.type)
         {
            case "ImportDecl":
               _frames.pop();
               return false;
            case "Block":
               _frames.pop();
               _frames.push({
                  "type":"BlockFrame",
                  "stmts":s.body,
                  "i":0,
                  "inFunction":fr.inFunction
               });
               return true;
            case "VarDecl":
               if(fr.state == 0)
               {
                  var varInit:* = s["init"];
                  var varName:String = String(s["name"]);
                  if(varInit != null)
                  {
                     fr["state"] = 1;
                     fr["name"] = varName;
                     _frames.push({
                        "type":"EvalFrame",
                        "node":varInit,
                        "state":0
                     });
                     return true;
                  }
                  envSet(varName,undefined);
                  _frames.pop();
                  return false;
               }
               var vv:* = consumeValue(popValue(),true);
               envSet(String(fr["name"]),vv);
               _frames.pop();
               return false;
               break;
            case "Assign":
               return tickAssignStmtFrame(fr,s);
            case "ExprStmt":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":s.expr,
                     "state":0
                  });
                  return true;
               }
               popValue();
               _frames.pop();
               return false;
               break;
            case "If":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.test = s.test;
                  fr.cons = s.cons;
                  fr.alt = s.alt;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.test,
                     "state":0
                  });
                  return true;
               }
               var tv:* = consumeValue(popValue(),true);
               _frames.pop();
               _frames.push({
                  "type":"StmtFrame",
                  "node":(truthy(tv) ? fr.cons : (fr.alt ? fr.alt : {
                     "type":"Block",
                     "body":[]
                  })),
                  "state":0,
                  "inFunction":fr.inFunction
               });
               return true;
               break;
            case "While":
               _frames.pop();
               _frames.push({
                  "type":"WhileFrame",
                  "node":s,
                  "state":0,
                  "inFunction":fr.inFunction
               });
               return true;
            case "FunctionDecl":
               var fnObj:Object = {
                  "type":"UserFunction",
                  "params":s.params,
                  "body":s.body,
                  "envSnapshot":_envStack.concat()
               };
               envSet(s.name,fnObj);
               _frames.pop();
               return false;
            case "Return":
               if(!fr.inFunction)
               {
                  if(fr.state == 0 && s.arg != null)
                  {
                     fr.state = 1;
                     _frames.push({
                        "type":"EvalFrame",
                        "node":s.arg,
                        "state":0
                     });
                     return true;
                  }
                  if(fr.state == 1)
                  {
                     popValue();
                  }
                  CheatPanel.public::log("代码执行器：顶层 return 被忽略。");
                  _frames.length = 0;
                  return false;
               }
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.hasArg = s.arg != null;
                  if(s.arg != null)
                  {
                     _frames.push({
                        "type":"EvalFrame",
                        "node":s.arg,
                        "state":0
                     });
                     return true;
                  }
                  doReturnFromFunction(null);
                  return false;
               }
               var rv:* = fr.hasArg ? consumeValue(popValue(),true) : null;
               doReturnFromFunction(rv);
               return false;
               break;
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
      
      private function tickAssignStmtFrame(fr:Object, s:Object) : Boolean
      {
         var rawValue:*;
         var left:Object;
         var targetText:String;
         var alias:String;
         var importedBase:*;
         var directBase:*;
         try
         {
            if(int(fr["state"]) == 0)
            {
               fr["state"] = 1;
               fr["left"] = s["left"];
               fr["right"] = s["right"];
               setExecutionContext("赋值右侧：" + safeExprText(fr["right"]));
               _frames.push({
                  "type":"EvalFrame",
                  "node":fr["right"],
                  "state":0
               });
               return true;
            }
            if(int(fr["state"]) == 1)
            {
               rawValue = popValue();
               fr["rval"] = isPkgChain(rawValue) ? consumeValue(rawValue,true) : rawValue;
               left = fr["left"];
               targetText = safeExprText(left);
               setExecutionContext("赋值：" + targetText);
               if(left["type"] == "Name")
               {
                  envSet(String(left["value"]),fr["rval"]);
                  _frames.pop();
                  return false;
               }
               if(left["type"] == "Member")
               {
                  if(left["object"] != null && left["object"]["type"] == "Name")
                  {
                     alias = String(left["object"]["value"]);
                     if(_importMap.hasOwnProperty(alias))
                     {
                        importedBase = resolveImportedDefinition(alias);
                        if(importedBase === null || importedBase === undefined)
                        {
                           throw new Error("找不到导入类定义：" + String(_importMap[alias]));
                        }
                        writeMemberValue(importedBase,left["prop"],fr["rval"],targetText);
                        _frames.pop();
                        return false;
                     }
                  }
                  directBase = tryResolveDefinitionNodeDirect(left["object"]);
                  if(directBase !== null && directBase !== undefined)
                  {
                     writeMemberValue(directBase,left["prop"],fr["rval"],targetText);
                     _frames.pop();
                     return false;
                  }
                  fr["state"] = 2;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":left["object"],
                     "state":0
                  });
                  return true;
               }
               if(left["type"] == "Index")
               {
                  fr["state"] = 3;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":left["object"],
                     "state":0
                  });
                  return true;
               }
               throw new Error("赋值左侧必须是变量、成员属性或索引属性");
            }
            left = fr["left"];
            targetText = safeExprText(left);
            if(int(fr["state"]) == 2)
            {
               rawValue = popValue();
               fr["assignBase"] = isPkgChain(rawValue) ? consumeValue(rawValue,true) : rawValue;
               if(fr["assignBase"] === null || fr["assignBase"] === undefined)
               {
                  throw new Error("成员赋值对象为 null：" + safeExprText(left["object"]));
               }
               writeMemberValue(fr["assignBase"],left["prop"],fr["rval"],targetText);
               _frames.pop();
               return false;
            }
            if(int(fr["state"]) == 3)
            {
               rawValue = popValue();
               fr["assignBase"] = isPkgChain(rawValue) ? consumeValue(rawValue,true) : rawValue;
               if(fr["assignBase"] === null || fr["assignBase"] === undefined)
               {
                  throw new Error("索引赋值对象为 null：" + safeExprText(left["object"]));
               }
               fr["state"] = 4;
               _frames.push({
                  "type":"EvalFrame",
                  "node":left["index"],
                  "state":0
               });
               return true;
            }
            rawValue = popValue();
            fr["assignIndex"] = isPkgChain(rawValue) ? consumeValue(rawValue,true) : rawValue;
            writeMemberValue(fr["assignBase"],fr["assignIndex"],fr["rval"],targetText);
            _frames.pop();
            return false;
         }
         catch(err:Error)
         {
            targetText = fr != null && fr["left"] != null ? safeExprText(fr["left"]) : safeExprText(s["left"]);
            throw new Error("赋值失败：" + targetText + "\n" + err.name + ": " + err.message);
         }
      }
      
      private function resolveImportedDefinition(alias:String) : *
      {
         var cached:*;
         var className:String;
         var def:*;
         if(alias == null || !_importMap.hasOwnProperty(alias))
         {
            return null;
         }
         cached = null;
         try
         {
            cached = _importValueMap[alias];
         }
         catch(cacheErr:Error)
         {
         }
         if(cached !== null && cached !== undefined)
         {
            return cached;
         }
         className = String(_importMap[alias]);
         def = resolveDefinitionByClassName(className);
         if(def !== null && def !== undefined)
         {
            try
            {
               _importValueMap[alias] = def;
            }
            catch(storeErr:Error)
            {
            }
         }
         return def;
      }
      
      private function resolveDefinitionByClassName(className:String) : *
      {
         var def:*;
         var i:int;
         var domain:ApplicationDomain;
         if(className == null || className.length == 0)
         {
            return null;
         }
         def = null;
         try
         {
            def = getDefinitionByName(className);
         }
         catch(getByNameErr:Error)
         {
         }
         if(def !== null && def !== undefined)
         {
            return def;
         }
         try
         {
            def = getDefinitionDeep(ApplicationDomain.currentDomain,className);
         }
         catch(currentDomainErr:Error)
         {
         }
         if(def !== null && def !== undefined)
         {
            return def;
         }
         if(_knownDomains.length == 0)
         {
            refreshKnownDomains();
         }
         i = 0;
         while(i < _knownDomains.length)
         {
            domain = _knownDomains[i] as ApplicationDomain;
            if(domain != null)
            {
               try
               {
                  if(domain.hasDefinition(className))
                  {
                     def = domain.getDefinition(className);
                     if(def !== null && def !== undefined)
                     {
                        return def;
                     }
                  }
               }
               catch(domainErr:Error)
               {
               }
            }
            i++;
         }
         return null;
      }
      
      private function tryResolveDefinitionNodeDirect(node:Object) : *
      {
         var className:String;
         var def:*;
         if(node == null)
         {
            return null;
         }
         className = buildChainString(node);
         if(className == null || className.length == 0 || className.indexOf("(") >= 0 || className.indexOf("[") >= 0)
         {
            return null;
         }
         def = null;
         try
         {
            def = getDefinitionByName(className);
         }
         catch(err:Error)
         {
         }
         if(def !== null && def !== undefined)
         {
            return def;
         }
         return getDefinitionDeep(ApplicationDomain.currentDomain,className);
      }
      
      private function tickWhileFrame(fr:Object) : Boolean
      {
         var w:Object = fr.node;
         if(fr.state == 0)
         {
            fr.state = 1;
            _frames.push({
               "type":"EvalFrame",
               "node":w.test,
               "state":0
            });
            return true;
         }
         if(fr.state == 1)
         {
            var tv:* = consumeValue(popValue(),true);
            if(!truthy(tv))
            {
               _frames.pop();
               return false;
            }
            fr.state = 0;
            if(w.body.type == "Block")
            {
               _frames.push({
                  "type":"BlockFrame",
                  "stmts":w.body.body,
                  "i":0,
                  "inFunction":fr.inFunction
               });
            }
            else
            {
               _frames.push({
                  "type":"BlockFrame",
                  "stmts":[w.body],
                  "i":0,
                  "inFunction":fr.inFunction
               });
            }
            return true;
         }
         return true;
      }
      
      private function handleBreakSignal() : void
      {
         while(_frames.length > 0)
         {
            var f:Object = _frames.pop();
            if(f.type == "WhileFrame")
            {
               return;
            }
         }
      }
      
      private function handleContinueSignal() : void
      {
         while(_frames.length > 0)
         {
            var f:Object = _frames.pop();
            if(f.type == "WhileFrame")
            {
               _frames.push(f);
               return;
            }
         }
      }
      
      private function tickCallUserFrame(fr:Object) : Boolean
      {
         if(fr.state == 0)
         {
            fr.state = 1;
            var localEnv:Dictionary = new Dictionary();
            var params:Array = fr.fn.params as Array;
            var i:int = 0;
            while(i < params.length)
            {
               var pName:String = params[i];
               localEnv[pName] = i < fr.args.length ? fr.args[i] : undefined;
               i++;
            }
            fr.savedStack = _envStack;
            _envStack = fr.fn.envSnapshot.concat();
            _envStack.push(localEnv);
            if(fr.fn.body.type == "Block")
            {
               _frames.push({
                  "type":"BlockFrame",
                  "stmts":fr.fn.body.body,
                  "i":0,
                  "inFunction":true
               });
            }
            else
            {
               _frames.push({
                  "type":"BlockFrame",
                  "stmts":[fr.fn.body],
                  "i":0,
                  "inFunction":true
               });
            }
            return true;
         }
         if(fr.state == 1)
         {
            _envStack = fr.savedStack;
            pushValue(null);
            _frames.pop();
            return false;
         }
         return true;
      }
      
      private function doReturnFromFunction(v:*) : void
      {
         while(_frames.length > 0)
         {
            var f:Object = _frames[_frames.length - 1];
            if(f.type == "CallUserFrame")
            {
               _envStack = f.savedStack;
               pushValue(v);
               _frames.pop();
               return;
            }
            _frames.pop();
         }
      }
      
      private function hasDefinitionDeep(domain:ApplicationDomain, name:String) : Boolean
      {
         var d:ApplicationDomain;
         var i:int;
         if(name == null || name.length == 0)
         {
            return false;
         }
         d = domain;
         while(d)
         {
            try
            {
               if(d.hasDefinition(name))
               {
                  return true;
               }
            }
            catch(err:Error)
            {
            }
            d = d.parentDomain;
         }
         if(_knownDomains.length == 0)
         {
            refreshKnownDomains();
         }
         i = 0;
         while(i < _knownDomains.length)
         {
            d = _knownDomains[i] as ApplicationDomain;
            try
            {
               if(d != null && d.hasDefinition(name))
               {
                  return true;
               }
            }
            catch(err2:Error)
            {
            }
            i++;
         }
         refreshKnownDomains();
         i = 0;
         while(i < _knownDomains.length)
         {
            d = _knownDomains[i] as ApplicationDomain;
            try
            {
               if(d != null && d.hasDefinition(name))
               {
                  return true;
               }
            }
            catch(err3:Error)
            {
            }
            i++;
         }
         return false;
      }
      
      private function getDefinitionDeep(domain:ApplicationDomain, name:String) : *
      {
         var i:int;
         var d:ApplicationDomain = domain;
         while(d)
         {
            try
            {
               if(d.hasDefinition(name))
               {
                  return d.getDefinition(name);
               }
            }
            catch(err:Error)
            {
            }
            d = d.parentDomain;
         }
         if(_knownDomains.length == 0)
         {
            refreshKnownDomains();
         }
         i = 0;
         while(i < _knownDomains.length)
         {
            d = _knownDomains[i] as ApplicationDomain;
            try
            {
               if(d != null && d.hasDefinition(name))
               {
                  return d.getDefinition(name);
               }
            }
            catch(err2:Error)
            {
            }
            i++;
         }
         refreshKnownDomains();
         i = 0;
         while(i < _knownDomains.length)
         {
            d = _knownDomains[i] as ApplicationDomain;
            try
            {
               if(d != null && d.hasDefinition(name))
               {
                  return d.getDefinition(name);
               }
            }
            catch(err3:Error)
            {
            }
            i++;
         }
         return null;
      }
      
      private function refreshKnownDomains() : void
      {
         _knownDomains = [];
         var seenDomains:Dictionary = new Dictionary(true);
         var seenObjects:Dictionary = new Dictionary(true);
         addKnownDomain(ApplicationDomain.currentDomain,seenDomains);
         if(stage != null)
         {
            collectDomainsFromDisplayTree(stage,seenObjects,seenDomains);
         }
         else if(root != null)
         {
            collectDomainsFromDisplayTree(root,seenObjects,seenDomains);
         }
      }
      
      private function addKnownDomain(domain:ApplicationDomain, seen:Dictionary) : void
      {
         var d:ApplicationDomain = domain;
         while(d != null)
         {
            if(!seen[d])
            {
               seen[d] = true;
               _knownDomains.push(d);
            }
            d = d.parentDomain;
         }
      }
      
      private function collectDomainsFromDisplayTree(obj:DisplayObject, seenObjects:Dictionary, seenDomains:Dictionary) : void
      {
         var container:DisplayObjectContainer;
         var i:int;
         if(obj == null || seenObjects[obj])
         {
            return;
         }
         seenObjects[obj] = true;
         try
         {
            if(obj.loaderInfo != null)
            {
               addKnownDomain(obj.loaderInfo.applicationDomain,seenDomains);
            }
         }
         catch(err:Error)
         {
         }
         container = obj as DisplayObjectContainer;
         if(container == null)
         {
            return;
         }
         i = 0;
         while(i < container.numChildren)
         {
            try
            {
               collectDomainsFromDisplayTree(container.getChildAt(i),seenObjects,seenDomains);
            }
            catch(err2:Error)
            {
            }
            i++;
         }
      }
      
      private function isChainStartsWithUnboundRoot(node:Object) : Boolean
      {
         var root:String = getRootName(node);
         return root != null && isUnboundRootName(root);
      }
      
      private function tickEvalFrame(fr:Object) : Boolean
      {
         var av:*;
         var b:*;
         var a:*;
         var obj:*;
         var idxVal:*;
         var base:*;
         var ni:int;
         var _loc3_:*;
         var _loc4_:*;
         var resolvedNameValue:*;
         var e:Object = fr.node;
         setExecutionContext("表达式：" + safeExprText(e));
         switch(e.type)
         {
            case "Literal":
               _frames.pop();
               pushValue(e.value);
               return false;
            case "ArrayLiteral":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.arr = [];
                  fr.idx = 0;
               }
               if(fr.state == 2)
               {
                  fr.arr.push(consumeValue(popValue(),true));
                  fr.state = 1;
               }
               if(fr.idx < e.elements.length)
               {
                  fr.state = 2;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":e.elements[fr.idx],
                     "state":0
                  });
                  _loc3_ = fr;
                  _loc4_ = Number(_loc3_.idx) + 1;
                  _loc3_.idx = _loc4_;
                  return true;
               }
               _frames.pop();
               pushValue(fr.arr);
               return false;
               break;
            case "Unary":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.op = e.op;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":e.arg,
                     "state":0
                  });
                  return true;
               }
               av = consumeValue(popValue(),true);
               _frames.pop();
               pushValue(fr.op == "!" ? !truthy(av) : -Number(av));
               return false;
               break;
            case "Binary":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.op = e.op;
                  fr.leftNode = e.left;
                  fr.rightNode = e.right;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.leftNode,
                     "state":0
                  });
                  return true;
               }
               if(fr.state == 1)
               {
                  fr.a = consumeValue(popValue(),true);
                  fr.state = 2;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.rightNode,
                     "state":0
                  });
                  return true;
               }
               b = consumeValue(popValue(),true);
               a = fr.a;
               _frames.pop();
               pushValue(evalBinary(fr.op,a,b));
               return false;
               break;
            case "Name":
               try
               {
                  resolvedNameValue = evalName(e.value);
                  _frames.pop();
                  pushValue(resolvedNameValue);
                  return false;
               }
               catch(nameResolveErr:Error)
               {
                  throw new Error("解析名称失败：" + e.value + "\n" + nameResolveErr.name + ": " + nameResolveErr.message);
               }
               break;
            case "Member":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.prop = e.prop;
                  fr.objectNode = e.object;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.objectNode,
                     "state":0
                  });
                  return true;
               }
               obj = popValue();
               if(isPkgChain(obj))
               {
                  _frames.pop();
                  pushValue(makePkgChain(e));
                  return false;
               }
               obj = consumeValue(obj,true);
               if(obj === null || obj === undefined)
               {
                  if(isChainStartsWithUnboundRoot(e))
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
               pushValue(readMemberValue(obj,fr.prop,buildChainString(e)));
               return false;
               break;
            case "Index":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.objectNode = e.object;
                  fr.indexNode = e.index;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.objectNode,
                     "state":0
                  });
                  return true;
               }
               if(fr.state == 1)
               {
                  fr.base = popValue();
                  fr.state = 2;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.indexNode,
                     "state":0
                  });
                  return true;
               }
               idxVal = consumeValue(popValue(),true);
               base = fr.base;
               if(isPkgChain(base))
               {
                  base = consumeValue(base,true);
               }
               if(base === null || base === undefined)
               {
                  if(isChainStartsWithUnboundRoot(e))
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
               pushValue(readMemberValue(base,idxVal,buildChainString(e)));
               return false;
               break;
            case "New":
               if(fr.state == 0)
               {
                  fr.state = 1;
                  fr.calleeNode = e.callee;
                  fr.argsNodes = e.args;
                  fr.argsVals = [];
                  fr.argi = 0;
                  _frames.push({
                     "type":"EvalFrame",
                     "node":fr.calleeNode,
                     "state":0
                  });
                  return true;
               }
               if(fr.state == 1)
               {
                  fr.ctor = consumeValue(popValue(),true);
                  fr.state = 2;
               }
               if(fr.state == 2)
               {
                  if(fr.argi < fr.argsNodes.length)
                  {
                     _frames.push({
                        "type":"EvalFrame",
                        "node":fr.argsNodes[fr.argi],
                        "state":0
                     });
                     _loc3_ = fr;
                     _loc4_ = Number(_loc3_.argi) + 1;
                     _loc3_.argi = _loc4_;
                     fr.state = 3;
                     return true;
                  }
                  _frames.pop();
                  ni = 0;
                  while(ni < fr.argsVals.length)
                  {
                     fr.argsVals[ni] = consumeValue(fr.argsVals[ni],true);
                     ni++;
                  }
                  if(fr.ctor is Class)
                  {
                     pushValue(constructClass(fr.ctor as Class,fr.argsVals));
                     return false;
                  }
                  throw new Error("new 目标不是 Class：" + describeValue(fr.ctor));
               }
               if(fr.state == 3)
               {
                  fr.argsVals.push(popValue());
                  fr.state = 2;
                  return true;
               }
               return true;
               break;
            case "Call":
               return tickCallExpr(fr,e);
            default:
               _frames.pop();
               pushValue(null);
               return false;
         }
      }
      
      private function tickCallExpr(fr:Object, e:Object) : Boolean
      {
         if(fr.state == 0)
         {
            setExecutionContext("调用：" + buildChainString(e.callee) + "(...)");
            fr.calleeNode = e.callee;
            fr.argsNodes = e.args;
            fr.argsVals = [];
            fr.argi = 0;
            fr.thisObj = null;
            fr.callKind = "value";
            if(e.callee.type == "Name")
            {
               var lname:String = String(e.callee.value).toLowerCase();
               if(_builtinNames.hasOwnProperty(lname))
               {
                  fr.callKind = "builtin";
                  fr.state = 10;
                  return true;
               }
               var uv:* = envGet(e.callee.value);
               if(isUserFunction(uv))
               {
                  fr.callKind = "user";
                  fr.userFn = uv;
                  fr.state = 10;
                  return true;
               }
            }
            if(e.callee.type == "Member")
            {
               fr.callKind = "member";
               fr.memberName = e.callee.prop;
               fr.state = 1;
               _frames.push({
                  "type":"EvalFrame",
                  "node":e.callee.object,
                  "state":0
               });
               return true;
            }
            if(e.callee.type == "Index")
            {
               fr.callKind = "index";
               fr.indexNode = e.callee.index;
               fr.state = 2;
               _frames.push({
                  "type":"EvalFrame",
                  "node":e.callee.object,
                  "state":0
               });
               return true;
            }
            fr.state = 3;
            _frames.push({
               "type":"EvalFrame",
               "node":e.callee,
               "state":0
            });
            return true;
         }
         if(fr.state == 1)
         {
            fr.thisObj = consumeValue(popValue(),true);
            if(fr.thisObj === null || fr.thisObj === undefined)
            {
               throw new Error("函数调用失败：接收对象为 null，目标 " + buildChainString(e.callee));
            }
            fr.calleeVal = readMemberValue(fr.thisObj,fr.memberName,buildChainString(e.callee));
            fr.state = 10;
         }
         else
         {
            if(fr.state == 2)
            {
               fr.thisObj = consumeValue(popValue(),true);
               if(fr.thisObj === null || fr.thisObj === undefined)
               {
                  throw new Error("函数调用失败：索引接收对象为 null，目标 " + buildChainString(e.callee));
               }
               fr.state = 4;
               _frames.push({
                  "type":"EvalFrame",
                  "node":fr.indexNode,
                  "state":0
               });
               return true;
            }
            if(fr.state == 4)
            {
               fr.indexValue = consumeValue(popValue(),true);
               fr.calleeVal = readMemberValue(fr.thisObj,fr.indexValue,buildChainString(e.callee));
               fr.state = 10;
            }
            else if(fr.state == 3)
            {
               fr.calleeVal = consumeValue(popValue(),true);
               fr.state = 10;
            }
         }
         if(fr.state == 10)
         {
            if(fr.argi < fr.argsNodes.length)
            {
               fr.state = 11;
               _frames.push({
                  "type":"EvalFrame",
                  "node":fr.argsNodes[fr.argi],
                  "state":0
               });
               fr.argi = Number(fr.argi) + 1;
               return true;
            }
            fr.state = 12;
         }
         if(fr.state == 11)
         {
            fr.argsVals.push(popValue());
            fr.state = 10;
            return true;
         }
         if(fr.state == 12)
         {
            var ii:int = 0;
            while(ii < fr.argsVals.length)
            {
               fr.argsVals[ii] = consumeValue(fr.argsVals[ii],true);
               ii++;
            }
            if(fr.callKind == "builtin")
            {
               var builtin:* = tryEvalBuiltinCallVM(e.callee,fr.argsVals);
               if(builtin === BUILTIN_NOT_MATCHED)
               {
                  throw new Error("内置函数解析失败：" + buildChainString(e.callee));
               }
               _frames.pop();
               pushValue(builtin);
               return false;
            }
            if(fr.callKind == "user" || isUserFunction(fr.calleeVal))
            {
               _frames.pop();
               _frames.push({
                  "type":"CallUserFrame",
                  "fn":(fr.callKind == "user" ? fr.userFn : fr.calleeVal),
                  "args":fr.argsVals,
                  "state":0
               });
               return true;
            }
            ii = 0;
            while(ii < fr.argsVals.length)
            {
               if(isUserFunction(fr.argsVals[ii]))
               {
                  fr.argsVals[ii] = wrapUserFunction(fr.argsVals[ii]);
               }
               ii++;
            }
            _frames.pop();
            pushValue(invokeCallable(fr.calleeVal,fr.thisObj,fr.argsVals,buildChainString(e.callee)));
            return false;
         }
         return true;
      }
      
      private function pushValue(v:*) : void
      {
         _valueStack.push(v);
      }
      
      private function popValue() : *
      {
         return _valueStack.pop();
      }
      
      private function envGet(name:String) : *
      {
         var i:int = _envStack.length - 1;
         while(i >= 0)
         {
            var d:Dictionary = _envStack[i];
            if(name in d)
            {
               return d[name];
            }
            i--;
         }
         return undefined;
      }
      
      private function isUnboundRootName(name:String) : Boolean
      {
         if(_builtinNames.hasOwnProperty(name.toLowerCase()))
         {
            return false;
         }
         if(_importMap.hasOwnProperty(name))
         {
            return false;
         }
         var v:* = envGet(name);
         if(v !== undefined)
         {
            return false;
         }
         if(name == "true" || name == "false" || name == "null")
         {
            return false;
         }
         if(!isValidIdent(name))
         {
            return false;
         }
         return true;
      }
      
      private function isValidIdent(s:String) : Boolean
      {
         return s != null && s.length > 0;
      }
      
      private function envSet(name:String, v:*) : void
      {
         Dictionary(_envStack[_envStack.length - 1])[name] = v;
      }
      
      private function truthy(v:*) : Boolean
      {
         return !(v === false || v === 0 || v == null || v === undefined);
      }
      
      private function isUserFunction(v:*) : Boolean
      {
         if(!safeHasOwnProperty(v,"type"))
         {
            return false;
         }
         try
         {
            return Object(v)["type"] == "UserFunction";
         }
         catch(err:Error)
         {
         }
         return false;
      }
      
      private function evalName(name:String) : *
      {
         if(_builtinNames.hasOwnProperty(name.toLowerCase()))
         {
            return name;
         }
         if(_importMap.hasOwnProperty(name))
         {
            var importedDef:* = resolveImportedDefinition(name);
            if(importedDef !== null && importedDef !== undefined)
            {
               return importedDef;
            }
            throw new Error("找不到导入类定义：" + String(_importMap[name]));
         }
         var v:* = envGet(name);
         if(v !== undefined)
         {
            return v;
         }
         if(isUnboundRootName(name))
         {
            return makePkgChain({
               "type":"Name",
               "value":name
            });
         }
         return evalByReflection({
            "type":"Name",
            "value":name
         });
      }
      
      private function wrapUserFunction(fnObj:Object) : Function
      {
         var self:CheatCodeExecutorControl;
         var f:Function;
         if(safeHasOwnProperty(fnObj,"__wrapped"))
         {
            try
            {
               if(Object(fnObj)["__wrapped"] is Function)
               {
                  return Object(fnObj)["__wrapped"] as Function;
               }
            }
            catch(err:Error)
            {
            }
         }
         self = this;
         f = function(... args):*
         {
            var valueDepth:int = int(self._valueStack.length);
            var callFrame:Object = {
               "type":"CallUserFrame",
               "fn":fnObj,
               "args":args,
               "state":0
            };
            self._frames.push(callFrame);
            while(self._frames.indexOf(callFrame) >= 0 && !self._isPaused)
            {
               self.processTopFrameOnce();
            }
            if(self._isPaused)
            {
               return null;
            }
            if(self._valueStack.length > valueDepth)
            {
               return self._valueStack.pop();
            }
            return null;
         };
         try
         {
            Object(fnObj)["__wrapped"] = f;
         }
         catch(e:Error)
         {
         }
         return f;
      }
      
      private function execAssign(left:Object, rv:*) : *
      {
         if(left.type == "Name")
         {
            envSet(left.value,rv);
            return rv;
         }
         if(left.type == "Member")
         {
            var obj:* = evalChainOrObject(left.object);
            if(obj === null || obj === undefined)
            {
               throw new Error("成员赋值失败：对象为 null，目标 " + buildChainString(left));
            }
            writeMemberValue(obj,left.prop,rv,buildChainString(left));
            return rv;
         }
         if(left.type == "Index")
         {
            var base:* = evalChainOrObject(left.object);
            if(base === null || base === undefined)
            {
               throw new Error("索引赋值失败：对象为 null，目标 " + buildChainString(left));
            }
            var idx:* = consumeValue(evalExprSync(left.index),true);
            writeMemberValue(base,idx,rv,buildChainString(left));
            return rv;
         }
         throw new Error("赋值左侧必须是变量、成员属性或索引属性");
      }
      
      private function evalChainOrObject(node:Object) : *
      {
         var v:* = evalExprSync(node);
         v = consumeValue(v,true);
         if(v === null || v === undefined)
         {
            if(isChainStartsWithUnboundRoot(node))
            {
               v = evalChainByReflection(node);
               v = consumeValue(v,true);
            }
         }
         return v;
      }
      
      private function evalExprSync(e:Object) : *
      {
         switch(e.type)
         {
            case "Literal":
               return e.value;
            case "Name":
               return evalName(e.value);
            case "Member":
               var o:* = evalExprSync(e.object);
               if(isPkgChain(o))
               {
                  return makePkgChain(e);
               }
               o = consumeValue(o,true);
               if(o == null)
               {
                  return null;
               }
               return readMemberValue(o,e.prop,buildChainString(e));
               break;
            case "Index":
               var b:* = evalExprSync(e.object);
               if(isPkgChain(b))
               {
                  b = consumeValue(b,true);
               }
               if(b == null)
               {
                  return null;
               }
               var k:* = consumeValue(evalExprSync(e.index),true);
               return readMemberValue(b,k,buildChainString(e));
               break;
            case "Unary":
               var av:* = consumeValue(evalExprSync(e.arg),true);
               return e.op == "!" ? !truthy(av) : -Number(av);
            case "Binary":
               return evalBinary(e.op,consumeValue(evalExprSync(e.left),true),consumeValue(evalExprSync(e.right),true));
            case "Call":
               var args:Array = [];
               for each(var an in e.args)
               {
                  args.push(consumeValue(evalExprSync(an),true));
               }
               return evalCallByReflectionValues(e.callee,args);
            case "New":
               var ctor:* = consumeValue(evalExprSync(e.callee),true);
               var avs:Array = [];
               for each(var nn in e.args)
               {
                  avs.push(consumeValue(evalExprSync(nn),true));
               }
               if(ctor is Class)
               {
                  return constructClass(ctor as Class,avs);
               }
               throw new Error("new 目标不是 Class：" + describeValue(ctor));
               break;
            case "ArrayLiteral":
               var arr:Array = [];
               for each(var el in e.elements)
               {
                  arr.push(consumeValue(evalExprSync(el),true));
               }
               return arr;
            default:
               return null;
         }
      }
      
      private function evalBinary(op:String, a:*, b:*) : *
      {
         switch(op)
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
      
      private function tryEvalBuiltinCallVM(calleeNode:Object, argVals:Array) : *
      {
         if(calleeNode.type != "Name")
         {
            return BUILTIN_NOT_MATCHED;
         }
         var lname:String = String(calleeNode.value).toLowerCase();
         if(lname == "delay")
         {
            return evalBuiltinDelayVM(argVals);
         }
         if(lname == "log")
         {
            return evalBuiltinLogVM(argVals);
         }
         if(lname == "click")
         {
            return evalBuiltinClickVM(argVals);
         }
         if(lname == "getcolor")
         {
            return evalBuiltinGetColorVM(argVals);
         }
         if(lname == "findwidget")
         {
            return evalBuiltinFindWidgetVM(argVals);
         }
         return BUILTIN_NOT_MATCHED;
      }
      
      private function evalBuiltinLogVM(argVals:Array) : *
      {
         var parts:Array = [];
         for each(var v in argVals)
         {
            parts.push(String(v));
         }
         CheatPanel.public::log(parts.join(" "));
         return null;
      }
      
      private function evalBuiltinDelayVM(argVals:Array) : *
      {
         var ms:int;
         var self:CheatCodeExecutorControl;
         if(argVals.length != 1)
         {
            throw new Error("Delay(ms) 只接受1个参数");
         }
         ms = int(argVals[0]);
         _isPaused = true;
         self = this;
         setTimeout(function():void
         {
            self._isPaused = false;
            try
            {
               self.pump();
            }
            catch(err:Error)
            {
               self.reportExecutionError(err);
               self._frames = [];
               self._runningAst = null;
               self._isPaused = false;
            }
         },ms);
         return null;
      }
      
      private function evalBuiltinClickVM(argVals:Array) : *
      {
         if(argVals.length < 2 || argVals.length > 3)
         {
            throw new Error("click(x, y, verbose=false) 只接受 2 或 3 个参数");
         }
         var x:Number = Number(argVals[0]);
         var y:Number = Number(argVals[1]);
         var verbose:Boolean = argVals.length == 3 ? truthy(argVals[2]) : false;
         clickAt(x,y,verbose);
         return null;
      }
      
      private function evalBuiltinFindWidgetVM(argVals:Array) : *
      {
         if(argVals.length != 1)
         {
            throw new Error("findWidget(fullClassName) 只接受 1 个参数");
         }
         if(!stage)
         {
            CheatPanel.public::log("findWidget 失败：stage 为 null");
            return null;
         }
         var className:String = String(argVals[0]);
         if(!className || className.replace(/\s+/g,"") == "")
         {
            CheatPanel.public::log("findWidget 失败：类名为空");
            return null;
         }
         var domain:ApplicationDomain = ApplicationDomain.currentDomain;
         if(!hasDefinitionDeep(domain,className))
         {
            CheatPanel.public::log("findWidget 找不到类定义：" + className);
            return null;
         }
         var def:* = getDefinitionDeep(domain,className);
         if(!(def is Class))
         {
            CheatPanel.public::log("findWidget 失败：定义不是 Class：" + className);
            return null;
         }
         var cls:Class = def as Class;
         return findDisplayObjectByClass(stage,cls);
      }
      
      private function findDisplayObjectByClass(root:DisplayObject, cls:Class) : DisplayObject
      {
         if(root == null)
         {
            return null;
         }
         if(root is cls)
         {
            return root;
         }
         var container:DisplayObjectContainer = root as DisplayObjectContainer;
         if(container == null)
         {
            return null;
         }
         var n:int = container.numChildren;
         var i:int = 0;
         while(i < n)
         {
            var child:DisplayObject = container.getChildAt(i);
            var hit:DisplayObject = findDisplayObjectByClass(child,cls);
            if(hit != null)
            {
               return hit;
            }
            i++;
         }
         return null;
      }
      
      private function evalBuiltinGetColorVM(argVals:Array) : *
      {
         if(argVals.length != 2)
         {
            throw new Error("getColor(x, y) 只接受 2 个参数");
         }
         return getColorAt(int(argVals[0]),int(argVals[1]));
      }
      
      private function getColorAt(stageX:int, stageY:int) : uint
      {
         var bmd:BitmapData;
         var m:Matrix;
         var c:uint;
         if(!stage)
         {
            CheatPanel.public::log("getColorAt 失败：stage 为 null");
            return 0;
         }
         try
         {
            if(stageX < 0 || stageY < 0 || stageX >= stage.stageWidth || stageY >= stage.stageHeight)
            {
               CheatPanel.public::log("getColorAt 越界: (" + stageX + "," + stageY + ")");
               return 0;
            }
            bmd = new BitmapData(1,1,true,0);
            m = new Matrix();
            m.translate(-stageX,-stageY);
            bmd.draw(stage,m,null,null,new Rectangle(0,0,1,1),true);
            c = bmd.getPixel32(0,0);
            bmd.dispose();
            return c;
         }
         catch(err:Error)
         {
            CheatPanel.public::log("getColorAt 出错: " + err.message);
         }
         return 0;
      }
      
      private function clickAt(stageX:Number, stageY:Number, verbose:Boolean = false) : void
      {
         var globalPt:Point;
         var list:Array;
         var chosenIO:InteractiveObject;
         var chosenOriginal:DisplayObject;
         var i:int;
         var target:DisplayObject;
         var originalTarget:DisplayObject;
         var io:InteractiveObject;
         var localPt:Point;
         var stageLocal:Point;
         if(!stage)
         {
            if(verbose)
            {
               CheatPanel.public::log("clickAt 失败：stage 为 null，无法点击 (" + stageX + ", " + stageY + ")");
            }
            return;
         }
         try
         {
            globalPt = new Point(stageX,stageY);
            list = stage.getObjectsUnderPoint(globalPt);
            chosenIO = null;
            chosenOriginal = null;
            if(list && list.length > 0)
            {
               i = list.length - 1;
               while(i >= 0)
               {
                  target = list[i];
                  originalTarget = target;
                  while(target && !(target is InteractiveObject))
                  {
                     target = target.parent;
                  }
                  io = target as InteractiveObject;
                  if(io)
                  {
                     chosenIO = io;
                     chosenOriginal = originalTarget;
                     break;
                  }
                  i--;
               }
               if(chosenIO)
               {
                  localPt = chosenIO.globalToLocal(globalPt);
                  chosenIO.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true,false,localPt.x,localPt.y));
                  chosenIO.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true,false,localPt.x,localPt.y));
                  chosenIO.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true,false,localPt.x,localPt.y));
                  if(verbose)
                  {
                     CheatPanel.public::log("clickAt 成功：已点击对象 [" + chosenIO.name + "] @ (" + stageX + ", " + stageY + ")，原始命中为 " + chosenOriginal.toString());
                  }
                  return;
               }
               if(verbose)
               {
                  CheatPanel.public::log("clickAt 提示：(" + stageX + ", " + stageY + ") 命中链上没有 InteractiveObject，改为点击 stage。");
               }
            }
            else if(verbose)
            {
               CheatPanel.public::log("clickAt 提示：(" + stageX + ", " + stageY + ") 下没有任何显示对象，改为点击 stage。");
            }
            stageLocal = stage.globalToLocal(globalPt);
            stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_DOWN,true,false,stageLocal.x,stageLocal.y));
            stage.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP,true,false,stageLocal.x,stageLocal.y));
            stage.dispatchEvent(new MouseEvent(MouseEvent.CLICK,true,false,stageLocal.x,stageLocal.y));
            if(verbose)
            {
               CheatPanel.public::log("clickAt 已向 stage 派发点击事件 @ (" + stageX + ", " + stageY + ")");
            }
         }
         catch(err:Error)
         {
            if(verbose)
            {
               CheatPanel.public::log("clickAt 调用出错：" + err.message);
            }
         }
      }
      
      private function evalCallByReflectionValues(calleeNode:Object, argVals:Array) : *
      {
         var resolved:Object = resolveCalleeValue(calleeNode);
         return invokeCallable(resolved.fn,resolved.thisObj,argVals,buildChainString(calleeNode));
      }
      
      private function resolveCalleeValue(node:Object) : Object
      {
         if(node.type == "Name")
         {
            var v:* = envGet(node.value);
            if(isUserFunction(v))
            {
               return {
                  "fn":wrapUserFunction(v),
                  "thisObj":null
               };
            }
            if(v !== undefined)
            {
               return {
                  "fn":v,
                  "thisObj":null
               };
            }
            if(_importMap.hasOwnProperty(node.value))
            {
               v = evalExpression2(_importMap[node.value],true);
            }
            else
            {
               v = consumeValue(evalName(node.value),true);
            }
            return {
               "fn":v,
               "thisObj":null
            };
         }
         if(node.type == "Member")
         {
            var base:* = consumeValue(evalExprSync(node.object),true);
            if(base === null || base === undefined)
            {
               return {
                  "fn":null,
                  "thisObj":null
               };
            }
            return {
               "fn":readMemberValue(base,node.prop,buildChainString(node)),
               "thisObj":base
            };
         }
         if(node.type == "Index")
         {
            base = consumeValue(evalExprSync(node.object),true);
            if(base === null || base === undefined)
            {
               return {
                  "fn":null,
                  "thisObj":null
               };
            }
            var key:* = consumeValue(evalExprSync(node.index),true);
            return {
               "fn":readMemberValue(base,key,buildChainString(node)),
               "thisObj":base
            };
         }
         v = consumeValue(evalExprSync(node),true);
         return {
            "fn":v,
            "thisObj":null
         };
      }
      
      private function invokeCallable(callable:*, thisObj:*, args:Array, targetText:String) : *
      {
         var fn:Function;
         if(!(callable is Function))
         {
            throw new Error("调用目标不是 Function：" + targetText + "，实际值 " + describeValue(callable));
         }
         fn = callable as Function;
         if(fn == null)
         {
            throw new Error("调用目标无法转换为 Function：" + targetText + "，实际值 " + describeValue(callable));
         }
         try
         {
            return fn.apply(thisObj,args);
         }
         catch(err:Error)
         {
            throw new Error("调用目标函数失败：" + targetText + "\n接收对象：" + describeValue(thisObj) + "\n" + err.name + ": " + err.message);
         }
      }
      
      private function readMemberValue(base:*, key:*, targetText:String) : *
      {
         var directError:Error;
         var direct:*;
         var namespaced:Object;
         if(base === null || base === undefined)
         {
            throw new Error("读取成员失败：对象为 null，目标 " + targetText);
         }
         directError = null;
         try
         {
            if(key in base)
            {
               return base[key];
            }
         }
         catch(inErr:Error)
         {
            directError = inErr;
         }
         try
         {
            direct = base[key];
            if(direct !== undefined)
            {
               return direct;
            }
         }
         catch(err:Error)
         {
            directError = err;
         }
         if(key is String)
         {
            namespaced = tryReadNamespacedMember(base,String(key));
            if(Boolean(namespaced.found))
            {
               return namespaced.value;
            }
         }
         if(directError != null)
         {
            throw new Error("读取成员失败：" + targetText + "，对象类型 " + describeValue(base) + "\n" + directError.name + ": " + directError.message + "\n该成员可能不是 public，或属于其他命名空间。");
         }
         return undefined;
      }
      
      private function writeMemberValue(base:*, key:*, value:*, targetText:String) : void
      {
         var directError:Error;
         var fallbackError:Error;
         var detail:String;
         if(base === null || base === undefined)
         {
            throw new Error("写入成员失败：对象为 null，目标 " + targetText);
         }
         directError = null;
         fallbackError = null;
         try
         {
            base[key] = value;
            return;
         }
         catch(err:Error)
         {
            directError = err;
         }
         if(key is String)
         {
            try
            {
               if(tryWriteNamespacedMember(base,String(key),value))
               {
                  return;
               }
            }
            catch(err2:Error)
            {
               fallbackError = err2;
            }
         }
         detail = "写入成员失败：" + targetText + " = " + literalToString(value) + "，对象类型 " + describeValue(base);
         if(directError != null)
         {
            detail += "\n直接写入：" + directError.name + ": " + directError.message;
         }
         if(fallbackError != null)
         {
            detail += "\n命名空间回退：" + fallbackError.name + ": " + fallbackError.message;
         }
         if(key is String)
         {
            detail += "\n运行时成员信息：" + describeMemberCandidates(base,String(key));
         }
         detail += "\n若成员信息中没有该名称，它可能不是 public/static，或属于不可访问的命名空间。";
         throw new Error(detail);
      }
      
      private function tryReadNamespacedMember(base:*, name:String) : Object
      {
         var info:XML;
         var node:XML;
         var result:Object;
         var uris:Array;
         var i:int;
         try
         {
            info = describeType(base);
         }
         catch(err:Error)
         {
            return {"found":false};
         }
         uris = collectMemberNamespaceUris(info,name,false);
         i = 0;
         while(i < uris.length)
         {
            result = tryReadQNameMember(base,name,String(uris[i]));
            if(Boolean(result.found))
            {
               return result;
            }
            i++;
         }
         return {"found":false};
      }
      
      private function tryReadQNameMember(base:*, name:String, uri:String) : Object
      {
         var qn:QName;
         try
         {
            qn = new QName(uri == null ? "" : uri,name);
            return {
               "found":true,
               "value":base[qn]
            };
         }
         catch(err:Error)
         {
         }
         return {"found":false};
      }
      
      private function tryWriteNamespacedMember(base:*, name:String, value:*) : Boolean
      {
         var info:XML;
         var uris:Array;
         var i:int;
         try
         {
            info = describeType(base);
         }
         catch(err:Error)
         {
            return false;
         }
         uris = collectMemberNamespaceUris(info,name,true);
         i = 0;
         while(i < uris.length)
         {
            if(tryWriteQNameMember(base,name,String(uris[i]),value))
            {
               return true;
            }
            i++;
         }
         return false;
      }
      
      private function collectMemberNamespaceUris(info:XML, name:String, writableOnly:Boolean) : Array
      {
         var node:XML;
         var access:String;
         var result:Array = [];
         var seen:Object = {};
         var addUri:Function = function(value:*):void
         {
            var uri:String = value == null ? "" : String(value);
            if(!seen.hasOwnProperty(uri))
            {
               seen[uri] = true;
               result.push(uri);
            }
         };
         if(!writableOnly)
         {
            for each(node in info..method)
            {
               if(String(node.@name) == name)
               {
                  addUri(String(node.@uri));
               }
            }
         }
         for each(node in info..accessor)
         {
            if(String(node.@name) == name)
            {
               access = String(node.@access);
               if(writableOnly ? access != "readonly" : access != "writeonly")
               {
                  addUri(String(node.@uri));
               }
            }
         }
         for each(node in info..variable)
         {
            if(String(node.@name) == name)
            {
               addUri(String(node.@uri));
            }
         }
         if(!writableOnly)
         {
            for each(node in info..constant)
            {
               if(String(node.@name) == name)
               {
                  addUri(String(node.@uri));
               }
            }
         }
         addUri("");
         addTypePackageUri(result,seen,String(info.@name));
         addTypePackageUri(result,seen,String(info.factory.@type));
         return result;
      }
      
      private function addTypePackageUri(result:Array, seen:Object, typeName:String) : void
      {
         if(typeName == null || typeName.length == 0)
         {
            return;
         }
         var split:int = typeName.lastIndexOf("::");
         if(split < 0)
         {
            split = typeName.lastIndexOf(".");
         }
         if(split <= 0)
         {
            return;
         }
         var uri:String = typeName.substring(0,split);
         if(!seen.hasOwnProperty(uri))
         {
            seen[uri] = true;
            result.push(uri);
         }
      }
      
      private function tryWriteQNameMember(base:*, name:String, uri:String, value:*) : Boolean
      {
         var qn:QName;
         try
         {
            qn = new QName(uri == null ? "" : uri,name);
            base[qn] = value;
            return true;
         }
         catch(err:Error)
         {
         }
         return false;
      }
      
      private function describeMemberCandidates(base:*, name:String) : String
      {
         var info:XML;
         var parts:Array;
         var node:XML;
         try
         {
            info = describeType(base);
         }
         catch(err:Error)
         {
            return "describeType 失败：" + err.name + ": " + err.message;
         }
         parts = [];
         for each(node in info..accessor)
         {
            if(String(node.@name) == name)
            {
               parts.push("accessor(access=" + String(node.@access) + ", uri=\'" + String(node.@uri) + "\')");
            }
         }
         for each(node in info..variable)
         {
            if(String(node.@name) == name)
            {
               parts.push("variable(uri=\'" + String(node.@uri) + "\', type=\'" + String(node.@type) + "\')");
            }
         }
         for each(node in info..constant)
         {
            if(String(node.@name) == name)
            {
               parts.push("constant(uri=\'" + String(node.@uri) + "\', type=\'" + String(node.@type) + "\')");
            }
         }
         for each(node in info..method)
         {
            if(String(node.@name) == name)
            {
               parts.push("method(uri=\'" + String(node.@uri) + "\')");
            }
         }
         if(parts.length == 0)
         {
            return "describeType 未发现名为 \'" + name + "\' 的 trait";
         }
         return parts.join(", ");
      }
      
      private function describeValue(value:*) : String
      {
         var className:String;
         var valueText:String;
         if(value === null)
         {
            return "null";
         }
         if(value === undefined)
         {
            return "undefined";
         }
         className = "?";
         valueText = "?";
         try
         {
            className = getQualifiedClassName(value);
         }
         catch(classErr:Error)
         {
         }
         try
         {
            valueText = String(value);
         }
         catch(stringErr:Error)
         {
            valueText = "<无法转换为字符串>";
         }
         return "[" + className + "] " + valueText;
      }
      
      private function evalByReflection(node:Object) : *
      {
         var s:String = buildChainString(node);
         return evalExpression2(s,true);
      }
      
      private function evalChainByReflection(node:Object) : *
      {
         var s:String = buildChainString(node);
         return evalExpression2(s,true);
      }
      
      private function buildChainString(node:Object) : String
      {
         if(node == null)
         {
            return "";
         }
         switch(node.type)
         {
            case "Name":
               if(_importMap.hasOwnProperty(node.value))
               {
                  return _importMap[node.value];
               }
               return node.value;
               break;
            case "Index":
               return buildChainString(node.object) + "[" + exprToString(node.index) + "]";
            case "Member":
               return buildChainString(node.object) + "." + node.prop;
            case "Call":
               var arr:Array = [];
               for each(var a in node.args)
               {
                  arr.push(exprToString(a));
               }
               return buildChainString(node.callee) + "(" + arr.join(",") + ")";
            case "New":
               arr = [];
               for each(a in node.args)
               {
                  arr.push(exprToString(a));
               }
               return "new " + buildChainString(node.callee) + "(" + arr.join(",") + ")";
            default:
               return exprToString(node);
         }
      }
      
      private function exprToString(e:Object) : String
      {
         if(e == null)
         {
            return "";
         }
         switch(e.type)
         {
            case "Literal":
               return literalToString(e.value);
            case "Name":
            case "Member":
            case "Call":
            case "Index":
            case "New":
               return buildChainString(e);
            case "Unary":
               return e.op + exprToString(e.arg);
            case "Binary":
               return "(" + exprToString(e.left) + e.op + exprToString(e.right) + ")";
            case "ArrayLiteral":
               var arr:Array = [];
               for each(var item in e.elements)
               {
                  arr.push(exprToString(item));
               }
               return "[" + arr.join(",") + "]";
            default:
               return "";
         }
      }
      
      private function literalToString(v:*) : String
      {
         if(v is String)
         {
            var s:String = String(v);
            s = s.replace(/\\/g,"\\\\");
            s = s.replace(/\"/g,"\\\"");
            s = s.replace(/\r/g,"\\r");
            s = s.replace(/\n/g,"\\n");
            s = s.replace(/\t/g,"\\t");
            return "\"" + s + "\"";
         }
         switch(v)
         {
            case null:
               return "null";
            case undefined:
               return "undefined";
            default:
               return String(v);
         }
      }
      
      private function getRootName(node:Object) : String
      {
         var cur:Object = node;
         while(cur != null)
         {
            if(cur.type == "Member" || cur.type == "Index")
            {
               cur = cur.object;
            }
            else if(cur.type == "Call")
            {
               cur = cur.callee;
            }
            else
            {
               if(cur.type != "New")
               {
                  break;
               }
               cur = cur.callee;
            }
         }
         if(cur && cur.type == "Name")
         {
            return cur.value;
         }
         return null;
      }
      
      private function evalExpression(expr:String) : *
      {
         return evalExpression2(expr,true);
      }
      
      private function evalExpression2(expr:String, logOnFail:Boolean) : *
      {
         var domain:ApplicationDomain;
         var firstSpecial:int;
         var searchEnd:int;
         var key:String;
         var cached:Object;
         var className:String;
         var classEnd:int;
         var lastOkName:String;
         var lastOkEnd:int;
         var i:int;
         var p:int;
         var cand:String;
         var cls:Class;
         var def:*;
         var current:*;
         var idx:int;
         var ch:String;
         var start:int;
         var name:String;
         var closeParen:int;
         var argsPart:String;
         var args:Array;
         var fn:*;
         var closeBracket:int;
         var indexText:String;
         var indexValue:*;
         expr = stripWhitespaceOutsideStrings(expr);
         if(expr == "")
         {
            if(logOnFail)
            {
               CheatPanel.public::log("代码执行器：表达式为空。");
            }
            return null;
         }
         domain = ApplicationDomain.currentDomain;
         firstSpecial = findFirstOutsideStrings(expr,"([");
         searchEnd = firstSpecial >= 0 ? firstSpecial : expr.length;
         key = expr.substring(0,searchEnd);
         cached = _classResolveCache[key];
         className = null;
         classEnd = 0;
         if(cached != null && cached.className != null)
         {
            className = cached.className;
            classEnd = int(cached.classEnd);
         }
         else
         {
            lastOkName = null;
            lastOkEnd = 0;
            i = 0;
            while(true)
            {
               p = expr.indexOf(".",i);
               if(p < 0 || p >= searchEnd)
               {
                  break;
               }
               cand = expr.substring(0,p);
               if(cand.length > 0 && hasDefinitionDeep(domain,cand))
               {
                  lastOkName = cand;
                  lastOkEnd = p;
               }
               i = p + 1;
            }
            if(searchEnd > 0)
            {
               cand = expr.substring(0,searchEnd);
               if(hasDefinitionDeep(domain,cand))
               {
                  lastOkName = cand;
                  lastOkEnd = searchEnd;
               }
            }
            className = lastOkName;
            classEnd = lastOkEnd;
            if(className != null)
            {
               _classResolveCache[key] = {
                  "className":className,
                  "classEnd":classEnd
               };
            }
         }
         if(!className)
         {
            if(logOnFail)
            {
               CheatPanel.public::log("代码执行器：找不到类前缀（已搜索当前域、父域和显示树中的子 SWF 域）：" + expr);
            }
            return null;
         }
         cls = _classCache[className] as Class;
         if(cls == null)
         {
            def = getDefinitionDeep(domain,className);
            if(!(def is Class))
            {
               if(logOnFail)
               {
                  CheatPanel.public::log("代码执行器：找到的定义不是 Class：" + className);
               }
               return null;
            }
            cls = def as Class;
            _classCache[className] = cls;
         }
         current = cls;
         idx = classEnd;
         while(idx < expr.length)
         {
            ch = expr.charAt(idx);
            if(ch == ".")
            {
               start = ++idx;
               while(idx < expr.length)
               {
                  ch = expr.charAt(idx);
                  if(!(ch >= "0" && ch <= "9" || ch >= "A" && ch <= "Z" || ch >= "a" && ch <= "z" || ch == "_" || ch == "$" || ch.charCodeAt(0) >= 128))
                  {
                     break;
                  }
                  idx++;
               }
               if(idx == start)
               {
                  if(logOnFail)
                  {
                     CheatPanel.public::log("代码执行器：缺少标识符：" + expr);
                  }
                  return current;
               }
               name = expr.substring(start,idx);
               if(idx < expr.length && expr.charAt(idx) == "(")
               {
                  closeParen = findMatchingDelimiter(expr,idx,"(",")");
                  if(closeParen < 0)
                  {
                     if(logOnFail)
                     {
                        CheatPanel.public::log("代码执行器：括号不匹配：" + expr);
                     }
                     return current;
                  }
                  argsPart = expr.substring(idx + 1,closeParen);
                  args = parseArgsExpression(argsPart);
                  try
                  {
                     fn = readMemberValue(current,name,className + expr.substring(classEnd,idx));
                     current = invokeCallable(fn,current,args,name);
                  }
                  catch(callErr:Error)
                  {
                     if(logOnFail)
                     {
                        CheatPanel.public::log("代码执行器：" + callErr.message);
                     }
                     return null;
                  }
                  idx = closeParen + 1;
               }
               else
               {
                  try
                  {
                     current = readMemberValue(current,name,className + expr.substring(classEnd,idx));
                  }
                  catch(readErr:Error)
                  {
                     if(logOnFail)
                     {
                        CheatPanel.public::log("代码执行器：" + readErr.message);
                     }
                     return null;
                  }
               }
            }
            else
            {
               if(ch != "[")
               {
                  if(logOnFail)
                  {
                     CheatPanel.public::log("代码执行器：语法错误，期望成员访问符：" + expr.substring(idx));
                  }
                  return current;
               }
               closeBracket = findMatchingDelimiter(expr,idx,"[","]");
               if(closeBracket < 0)
               {
                  if(logOnFail)
                  {
                     CheatPanel.public::log("代码执行器：中括号不匹配：" + expr);
                  }
                  return current;
               }
               indexText = expr.substring(idx + 1,closeBracket);
               indexValue = parseSingleArg(indexText);
               try
               {
                  current = readMemberValue(current,indexValue,expr.substring(0,closeBracket + 1));
               }
               catch(indexErr:Error)
               {
                  if(logOnFail)
                  {
                     CheatPanel.public::log("代码执行器：" + indexErr.message);
                  }
                  return null;
               }
               idx = closeBracket + 1;
            }
         }
         return current;
      }
      
      private function stripWhitespaceOutsideStrings(value:String) : String
      {
         var out:String = "";
         var quote:String = "";
         var escaped:Boolean = false;
         var i:int = 0;
         while(i < value.length)
         {
            var ch:String = value.charAt(i);
            if(quote.length > 0)
            {
               out += ch;
               if(escaped)
               {
                  escaped = false;
               }
               else if(ch == "\\")
               {
                  escaped = true;
               }
               else if(ch == quote)
               {
                  quote = "";
               }
            }
            else if(ch == "\"" || ch == "\'")
            {
               quote = ch;
               out += ch;
            }
            else if(ch > " ")
            {
               out += ch;
            }
            i++;
         }
         return out;
      }
      
      private function findFirstOutsideStrings(value:String, chars:String) : int
      {
         var quote:String = "";
         var escaped:Boolean = false;
         var i:int = 0;
         while(i < value.length)
         {
            var ch:String = value.charAt(i);
            if(quote.length > 0)
            {
               if(escaped)
               {
                  escaped = false;
               }
               else if(ch == "\\")
               {
                  escaped = true;
               }
               else if(ch == quote)
               {
                  quote = "";
               }
            }
            else if(ch == "\"" || ch == "\'")
            {
               quote = ch;
            }
            else if(chars.indexOf(ch) >= 0)
            {
               return i;
            }
            i++;
         }
         return -1;
      }
      
      private function findMatchingDelimiter(value:String, start:int, openChar:String, closeChar:String) : int
      {
         var depth:int = 0;
         var quote:String = "";
         var escaped:Boolean = false;
         var i:int = start;
         while(i < value.length)
         {
            var ch:String = value.charAt(i);
            if(quote.length > 0)
            {
               if(escaped)
               {
                  escaped = false;
               }
               else if(ch == "\\")
               {
                  escaped = true;
               }
               else if(ch == quote)
               {
                  quote = "";
               }
            }
            else if(ch == "\"" || ch == "\'")
            {
               quote = ch;
            }
            else if(ch == openChar)
            {
               depth++;
            }
            else if(ch == closeChar)
            {
               if(--depth == 0)
               {
                  return i;
               }
            }
            i++;
         }
         return -1;
      }
      
      private function parseArgsExpression(argsPart:String) : Array
      {
         var args:Array = [];
         var parenDepth:int = 0;
         var bracketDepth:int = 0;
         var braceDepth:int = 0;
         var inStr:Boolean = false;
         var escaped:Boolean = false;
         var quoteChar:String = "";
         var cur:String = "";
         argsPart = argsPart.replace(/^\s+|\s+$/g,"");
         if(argsPart == "")
         {
            return args;
         }
         var i:int = 0;
         while(i < argsPart.length)
         {
            var ch:String = argsPart.charAt(i);
            if(inStr)
            {
               cur += ch;
               if(escaped)
               {
                  escaped = false;
               }
               else if(ch == "\\")
               {
                  escaped = true;
               }
               else if(ch == quoteChar)
               {
                  inStr = false;
               }
            }
            else if(ch == "\"" || ch == "\'")
            {
               inStr = true;
               quoteChar = ch;
               cur += ch;
            }
            else if(ch == "(")
            {
               parenDepth++;
               cur += ch;
            }
            else if(ch == ")")
            {
               parenDepth--;
               cur += ch;
            }
            else if(ch == "[")
            {
               bracketDepth++;
               cur += ch;
            }
            else if(ch == "]")
            {
               bracketDepth--;
               cur += ch;
            }
            else if(ch == "{")
            {
               braceDepth++;
               cur += ch;
            }
            else if(ch == "}")
            {
               braceDepth--;
               cur += ch;
            }
            else if(ch == "," && parenDepth == 0 && bracketDepth == 0 && braceDepth == 0)
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
         if(cur.length > 0)
         {
            args.push(parseSingleArg(cur));
         }
         return args;
      }
      
      private function parseSingleArg(s:String) : *
      {
         if(s == null)
         {
            return null;
         }
         s = s.replace(/^\s+|\s+$/g,"");
         if(s == "")
         {
            return null;
         }
         if(s == "true")
         {
            return true;
         }
         if(s == "false")
         {
            return false;
         }
         if(s == "null")
         {
            return null;
         }
         if(s == "undefined")
         {
            return undefined;
         }
         if(s.charAt(0) == "\"" && s.charAt(s.length - 1) == "\"" || s.charAt(0) == "\'" && s.charAt(s.length - 1) == "\'")
         {
            var value:String = s.substring(1,s.length - 1);
            value = value.replace(/\\n/g,"\n");
            value = value.replace(/\\r/g,"\r");
            value = value.replace(/\\t/g,"\t");
            value = value.replace(/\\\"/g,"\"");
            value = value.replace(/\\'/g,"\'");
            return value.replace(/\\\\/g,"\\");
         }
         if(/^0[xX][0-9a-fA-F]+$/.test(s))
         {
            return parseInt(s.substr(2),16);
         }
         if(/^-?\d+$/.test(s))
         {
            return int(s);
         }
         if(/^-?(?:\d+\.\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$/.test(s) || /^-?\d+[eE][+-]?\d+$/.test(s))
         {
            return Number(s);
         }
         var envValue:* = envGet(s);
         if(envValue !== undefined)
         {
            return envValue;
         }
         if(_importMap.hasOwnProperty(s))
         {
            return evalExpression2(_importMap[s],true);
         }
         if(s.indexOf(".") != -1 || s.indexOf("(") != -1 || s.indexOf("[") != -1)
         {
            return evalExpression2(s,true);
         }
         return s;
      }
      
      private function constructClass(cls:Class, args:Array) : *
      {
         var n:int = args ? args.length : 0;
         switch(n)
         {
            case 0:
               return new cls();
            case 1:
               return new cls(args[0]);
            case 2:
               return new cls(args[0],args[1]);
            case 3:
               return new cls(args[0],args[1],args[2]);
            case 4:
               return new cls(args[0],args[1],args[2],args[3]);
            case 5:
               return new cls(args[0],args[1],args[2],args[3],args[4]);
            case 6:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5]);
            case 7:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6]);
            case 8:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7]);
            case 9:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8]);
            case 10:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9]);
            case 11:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10]);
            case 12:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11]);
            case 13:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12]);
            case 14:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12],args[13]);
            case 15:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12],args[13],args[14]);
            case 16:
               return new cls(args[0],args[1],args[2],args[3],args[4],args[5],args[6],args[7],args[8],args[9],args[10],args[11],args[12],args[13],args[14],args[15]);
            default:
               throw new Error("new 参数过多（当前支持 0~16）");
         }
      }
   }
}

