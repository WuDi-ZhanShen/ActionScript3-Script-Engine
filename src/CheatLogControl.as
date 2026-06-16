package
{
   import flash.display.Sprite;
   import flash.events.MouseEvent;
   import flash.text.TextField;
   import flash.text.TextFormat;
   
   public class CheatLogControl extends Sprite
   {
      
      private static const MAX_LINES:int = 200;
      
      private var _field:TextField;
      
      private var _lines:Array;
      
      private var _btnClear:Sprite;
      
      private var _btnClearLabel:TextField;
      
      public function CheatLogControl()
      {
         super();
         _lines = [];
         buildUI();
      }
      
      private function buildUI() : void
      {
         var tf:TextFormat = new TextFormat("宋体",12,16777215);
         _field = new TextField();
         _field.defaultTextFormat = tf;
         _field.multiline = true;
         _field.wordWrap = true;
         _field.selectable = true;
         _field.text = "[日志]\n";
         addChild(_field);
         _btnClear = new Sprite();
         _btnClear.buttonMode = true;
         _btnClear.mouseChildren = false;
         _btnClear.addEventListener(MouseEvent.CLICK,onClearClick);
         _btnClear.graphics.beginFill(4473924,1);
         _btnClear.graphics.drawRoundRect(0,0,40,18,6,6);
         _btnClear.graphics.endFill();
         _btnClearLabel = new TextField();
         var tfBtn:TextFormat = new TextFormat("宋体",11,16777215,true);
         tfBtn.align = "center";
         _btnClearLabel.defaultTextFormat = tfBtn;
         _btnClearLabel.width = 40;
         _btnClearLabel.height = 18;
         _btnClearLabel.selectable = false;
         _btnClearLabel.text = "清空";
         _btnClearLabel.setTextFormat(tfBtn);
         _btnClearLabel.x = 0;
         _btnClearLabel.y = 0;
         _btnClear.addChild(_btnClearLabel);
         addChild(_btnClear);
         _btnClear.visible = false;
      }
      
      public function setSize(w:int, h:int) : void
      {
         _field.width = w;
         _field.height = h;
         if(_btnClear)
         {
            _btnClear.x = w - _btnClear.width - 2;
            _btnClear.y = 2;
         }
      }
      
      public function appendLog(msg:String) : void
      {
         if(!msg)
         {
            return;
         }
         _lines.push(msg);
         if(_lines.length > MAX_LINES)
         {
            _lines.shift();
         }
         if(_lines.length > 0)
         {
            _field.text = "[日志]\n" + _lines.join("\n");
         }
         else
         {
            _field.text = "[日志]\n";
         }
         try
         {
            _field.scrollV = _field.maxScrollV;
         }
         catch(e:Error)
         {
         }
         if(_btnClear)
         {
            _btnClear.visible = _lines.length > 0;
         }
      }
      
      private function onClearClick(e:MouseEvent) : void
      {
         _lines.length = 0;
         _field.text = "[日志]\n";
         try
         {
            _field.scrollV = 1;
         }
         catch(err:Error)
         {
         }
         if(_btnClear)
         {
            _btnClear.visible = false;
         }
      }
   }
}

