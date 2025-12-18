package
{
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;
	
	public class CheatPanel extends Sprite
	{
		
		private static var _instance:CheatPanel;
		
		public static const PANEL_WIDTH:int = 290;
		
		private static const COLLAPSED_HEIGHT:int = 40;
		
		private var _bg:Sprite;
		
		private var _title:TextField;
		
		private var _btnToggle:Sprite;
		
		private var _toggleLabel:TextField;
		
		private var _expanded:Boolean = true;
		
		private var _dragging:Boolean = false;
		
		private var _logControl:CheatLogControl;
		
		private var _preventDeactivateEnabled:Boolean = true;
		
		private var _buttonControls:Array;
		
		public function CheatPanel()
		{
			super();
			_instance = this;
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		public static function get instance():CheatPanel
		{
			return _instance;
		}
		
		public static function log(msg:String):void
		{
			if (_instance)
			{
				_instance.appendLog(msg);
			}
		}
		
		private function appendLog(msg:String):void
		{
			if (_logControl)
			{
				_logControl.appendLog(msg);
			}
		}
		
		private function onAddedToStage(e:Event):void
		{
			removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			this.x = 0;
			this.y = 0;
			buildUI();
			layoutPanel();
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
		}
		
		private function buildUI():void
		{
			var tfTitle:TextFormat = new TextFormat("宋体", 14, 16776960, true);
			_buttonControls = [];
			_bg = new Sprite();
			addChild(_bg);
			_bg.addEventListener(MouseEvent.MOUSE_DOWN, onDragStart);
			stage.addEventListener(MouseEvent.MOUSE_UP, onDragEnd);
			_title = new TextField();
			_title.defaultTextFormat = tfTitle;
			_title.width = PANEL_WIDTH - 60;
			_title.height = 20;
			_title.x = 5;
			_title.y = 2;
			_title.selectable = false;
			_title.mouseEnabled = true;                 // 确保能收 mouse 事件
			_title.text = "脚本执行器 (F1显示/隐藏)";
			addChild(_title);
			
			// 让标题也能拖
			_title.addEventListener(MouseEvent.MOUSE_DOWN, onDragStart);
			_title.addEventListener(MouseEvent.MOUSE_UP, onDragEnd); // 可选：更顺手
			
			_btnToggle = new Sprite();
			_btnToggle.buttonMode = true;
			_btnToggle.mouseChildren = false;
			_btnToggle.addEventListener(MouseEvent.CLICK, onToggleClick);
			_toggleLabel = new TextField();
			_toggleLabel.defaultTextFormat = new TextFormat("宋体", 12, 16777215, true);
			_toggleLabel.width = 40;
			_toggleLabel.height = 20;
			_toggleLabel.y = -2;
			_toggleLabel.selectable = false;
			_btnToggle.addChild(_toggleLabel);
			addChild(_btnToggle);
			updateToggleLabel();
			var cheatFrameRateToggleControl:CheatFrameRateToggleControl = new CheatFrameRateToggleControl();
			addChild(cheatFrameRateToggleControl);
			_buttonControls.push(cheatFrameRateToggleControl);
			var codeExec:CheatCodeExecutorControl = new CheatCodeExecutorControl();
			addChild(codeExec);
			_buttonControls.push(codeExec);
			_logControl = new CheatLogControl();
			addChild(_logControl);
		}
		
		private function onInfoToggleChange(e:Event):void
		{
			layoutPanel();
		}
		
		private function layoutPanel():void
		{
			if (stage)
			{
				var h:int = _expanded ? stage.stageHeight : COLLAPSED_HEIGHT;
			}
			else
			{
				h = _expanded ? 500 : COLLAPSED_HEIGHT;
			}
			_bg.graphics.clear();
			_bg.graphics.beginFill(0, 0.7);
			_bg.graphics.drawRect(0, 0, PANEL_WIDTH, h);
			_bg.graphics.endFill();
			_title.width = PANEL_WIDTH - 40;
			_btnToggle.x = PANEL_WIDTH - 45;
			_btnToggle.y = 5;
			if (!_expanded)
			{
				setChildrenVisible(false);
				return;
			}
			setChildrenVisible(true);
			var margin:int = 5;
			var y:int = 25;
			var contentBottom:int = h - margin;
			var contentHeight:int = contentBottom - y;
			var buttonsTotalHeight:int = 0;
			if (_buttonControls)
			{
				var i:int = 0;
				while (i < _buttonControls.length)
				{
					var ctrl:Sprite = _buttonControls[i] as Sprite;
					if (ctrl)
					{
						buttonsTotalHeight += ctrl.height + 5;
					}
					i++;
				}
			}
			var desiredInfoFull:int = 160;
			var infoHeight:int = 0;
			
			var logMinHeight:int = 80;
			var logHeight:int = contentHeight - infoHeight - buttonsTotalHeight - margin;
			if (logHeight < logMinHeight)
			{
				logHeight = logMinHeight;
				var minInfo:int = 20;
				var newInfoFull:int = contentHeight - buttonsTotalHeight - margin - logHeight;
				if (newInfoFull < minInfo)
				{
					newInfoFull = minInfo;
				}
				
			}
			
			if (_buttonControls)
			{
				i = 0;
				while (i < _buttonControls.length)
				{
					ctrl = _buttonControls[i] as Sprite;
					if (ctrl)
					{
						ctrl.x = margin;
						ctrl.y = y;
						y += ctrl.height + 5;
					}
					i++;
				}
			}
			if (_logControl)
			{
				_logControl.x = margin;
				_logControl.y = y;
				_logControl.setSize(PANEL_WIDTH - 10, logHeight);
				y += logHeight + 5;
			}
		}
		
		private function setChildrenVisible(v:Boolean):void
		{
			
			if (_logControl)
			{
				_logControl.visible = v;
			}
			if (_buttonControls)
			{
				var i:int = 0;
				while (i < _buttonControls.length)
				{
					var ctrl:Sprite = _buttonControls[i] as Sprite;
					if (ctrl)
					{
						ctrl.visible = v;
					}
					i++;
				}
			}
		}
		
		private function updateToggleLabel():void
		{
			if (_toggleLabel)
			{
				_toggleLabel.text = _expanded ? "收起" : "展开";
			}
		}
		
		private function onToggleClick(e:MouseEvent):void
		{
			_expanded = !_expanded;
			updateToggleLabel();
			layoutPanel();
		}
		
		private function onEnterFrame(e:Event):void
		{
			if (stage && parent == stage)
			{
				var topIndex:int = stage.numChildren - 1;
				if (stage.getChildIndex(this) != topIndex)
				{
					stage.setChildIndex(this, topIndex);
				}
			}
		}
		
		private function onDragStart(e:MouseEvent):void
		{
			startDrag();
			_dragging = true;
		}
		
		private function onDragEnd(e:MouseEvent):void
		{
			if (_dragging)
			{
				stopDrag();
				_dragging = false;
			}
		}
		
		private function onKeyDown(e:KeyboardEvent):void
		{
			if (e.keyCode == Keyboard.F1)
			{
				this.visible = !this.visible;
			}
		}
	}
}

