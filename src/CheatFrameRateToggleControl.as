package
{
	
	import flash.display.Sprite;
	import flash.display.StageQuality;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.net.SharedObject;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.text.TextFormat;
	import flash.display.Stage;
	import flash.utils.getTimer;
	
	// ...
	
	public class CheatFrameRateToggleControl extends Sprite
	{
		
		private static const SOL_NAME:String = "FrameRateToggleControl";
		
		private static const QUALITY_ORDER:Array = [StageQuality.LOW, StageQuality.MEDIUM, StageQuality.HIGH, StageQuality.BEST, StageQuality.HIGH_8X8, StageQuality.HIGH_8X8_LINEAR, StageQuality.HIGH_16X16, StageQuality.HIGH_16X16_LINEAR];
		
		private static const QUALITY_NAME:Array = ["低", "中", "高", "极高", "8X", "8X线性", "16X", "16X线性"];
		
		private static const QUALITY_AA:Array = ["抗锯齿:无", "抗锯齿:2X", "抗锯齿:4X", "抗锯齿:4X", "抗锯齿:8X", "抗锯齿:8X线性", "抗锯齿:16X", "抗锯齿:16X线性"];
		
		private static const QUALITY_SCALE:Array = ["缩放:多级纹理", "缩放:多级纹理", "缩放:多级纹理", "缩放:高阶插值", "缩放:高阶插值", "缩放:高阶插值", "缩放:高阶插值", "缩放:高阶插值"];
		
		private var _box:Sprite;
		
		private var _label:TextField;
		
		private var _frameInput:TextField;
		
		private var _so:SharedObject;
		
		private var _qualityTrack:Sprite;
		
		private var _qualityKnob:Sprite;
		
		private var _qualityPositions:Array;
		
		private var _qualityIndex:int = 1;
		
		private var _dragMinX:Number = 0;
		
		private var _dragMaxX:Number = 0;
		
		private var _draggingKnob:Boolean = false;
		
		private var _qualityInfoLabel:TextField;
		
		private var _frameRate:int = 60;
		private var _fpsLabel:TextField;
		
		private var _lastFpsTime:int = 0;
		private var _frameCount:int = 0;
		
		public function CheatFrameRateToggleControl()
		{
			super();
			buildUI();
			loadSettingFromSOL();
			updateQualityUI();
			addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
			addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
		}
		
		private function get curStage():Stage
		{
			// this.stage 在被 addChild 且进入显示列表后可用
			if (stage) return stage;
			
			// 兜底：有些老项目会把控件挂得比较深，可从 root 找
			if (root && root.stage) return root.stage;
			
			return null;
		}
		
		private function buildUI():void
		{
			var tf:TextFormat = new TextFormat("宋体", 11, 16777215);
			tf.align = "center";
			_frameInput = new TextField();
			_frameInput.defaultTextFormat = tf;
			_frameInput.type = TextFieldType.INPUT;
			_frameInput.border = true;
			_frameInput.background = true;
			_frameInput.backgroundColor = 0;
			_frameInput.text = "60";
			_frameInput.width = 40;
			_frameInput.height = 20;
			_frameInput.x = 30;
			_frameInput.y = 0;
			_frameInput.restrict = "0-9";
			_frameInput.maxChars = 3;
			addChild(_frameInput);
			var tfBtn:TextFormat = new TextFormat("宋体", 12, 16777215);
			tfBtn.align = "center";
			_box = new Sprite();
			_box.graphics.beginFill(4473924, 1);
			_box.graphics.drawRoundRect(0, 0, 70, 24, 8, 8);
			_box.graphics.endFill();
			_box.buttonMode = true;
			_box.mouseChildren = false;
			_box.x = _frameInput.x + _frameInput.width + 8;
			_box.y = -2;
			_label = new TextField();
			_label.defaultTextFormat = tfBtn;
			_label.width = 70;
			_label.height = 20;
			_label.x = 0;
			_label.y = 2;
			_label.selectable = false;
			_label.mouseEnabled = false;
			_label.text = "设置帧率";
			_box.addChild(_label);
			addChild(_box);
			_box.addEventListener(MouseEvent.CLICK, onBoxClick);
			
			// --- FPS label ---
			_fpsLabel = new TextField();
			_fpsLabel.defaultTextFormat = tf;
			_fpsLabel.selectable = false;
			_fpsLabel.mouseEnabled = false;
			_fpsLabel.width = 90;
			_fpsLabel.height = 20;
			
			// 放在第一行右侧，你可以按喜好微调
			_fpsLabel.x = 160;   // 因为总宽要到 250，所以右边留得下
			_fpsLabel.y = 0;
			_fpsLabel.text = "实时帧率: --";
			addChild(_fpsLabel);
			
			var secondRowY:int = 24;
			var trackWidth:Number = 220;
			_qualityTrack = new Sprite();
			_qualityTrack.x = 30;
			_qualityTrack.y = secondRowY;
			_qualityTrack.buttonMode = true;
			addChild(_qualityTrack);
			_qualityTrack.graphics.beginFill(6710886, 1);
			_qualityTrack.graphics.drawRect(0, 5, trackWidth, 2);
			_qualityTrack.graphics.endFill();
			_qualityPositions = [];
			var count:int = int(QUALITY_ORDER.length);
			var i:int = 0;
			while (i < count)
			{
				var px:Number = trackWidth * i / (count - 1);
				_qualityPositions.push(px);
				_qualityTrack.graphics.beginFill(16777215, 1);
				_qualityTrack.graphics.drawCircle(px, 6, 2);
				_qualityTrack.graphics.endFill();
				i++;
			}
			_qualityKnob = new Sprite();
			_qualityKnob.buttonMode = true;
			addChild(_qualityKnob);
			_qualityKnob.graphics.beginFill(16750848, 1);
			_qualityKnob.graphics.drawCircle(0, 0, 5);
			_qualityKnob.graphics.endFill();
			_qualityKnob.y = secondRowY + 6;
			_qualityInfoLabel = new TextField();
			_qualityInfoLabel.defaultTextFormat = tf;
			_qualityInfoLabel.width = 260;
			_qualityInfoLabel.height = 20;
			_qualityInfoLabel.x = 10;
			_qualityInfoLabel.y = secondRowY + 16;
			_qualityInfoLabel.selectable = false;
			addChild(_qualityInfoLabel);
			_qualityTrack.addEventListener(MouseEvent.CLICK, onQualityTrackClick);
			_qualityKnob.addEventListener(MouseEvent.MOUSE_DOWN, onQualityKnobMouseDown);
			_dragMinX = _qualityTrack.x + Number(_qualityPositions[0]);
			_dragMaxX = _qualityTrack.x + Number(_qualityPositions[_qualityPositions.length - 1]);
			buttonMode = false;
			mouseChildren = true;
		}
		
		override public function get height():Number
		{
			return 74;
		}
		
		private function onBoxClick(e:MouseEvent):void
		{
			if (_frameInput && _frameInput.text != "")
			{
				var fps:int = int(_frameInput.text);
			}
			if (fps <= 0)
			{
				fps = 60;
			}
			_frameRate = fps;
			applyFrameRate(_frameRate, true);
			saveSettingToSOL();
			e.stopImmediatePropagation();
		}
		
		private function onAddedToStage(e:Event):void
		{
			_lastFpsTime = getTimer();
			_frameCount = 0;
			
			addEventListener(Event.ENTER_FRAME, onEnterFrame);
		}
		
		private function onRemovedFromStage(e:Event):void
		{
			removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			if (stage && _draggingKnob)
			{
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
			}
			_draggingKnob = false;
		}
		
		private function onEnterFrame(e:Event):void
		{
			// 原来：确保控件置顶
			if (parent && parent.getChildIndex(this) != parent.numChildren - 1)
			{
				parent.setChildIndex(this, parent.numChildren - 1);
			}
			
			// --- FPS 统计 ---
			_frameCount++;
			var now:int = getTimer();
			var delta:int = now - _lastFpsTime;
			
			if (delta >= 1000)   // 每 1 秒刷新一次
			{
				var fps:Number = _frameCount * 1000 / delta;
				
				if (_fpsLabel)
				{
					// 显示 1 位小数，你想整数就用 int(fps)
					_fpsLabel.text = "实时帧率: " + fps.toFixed(1);
				}
				
				_frameCount = 0;
				_lastFpsTime = now;
			}
		}
		
		private function applyFrameRate(frame:int, showPrompt:Boolean = true):void
		{
			if (!curStage)
			{
				return;
			}
			if (frame <= 0)
			{
				frame = 1;
			}
			curStage.frameRate = frame;
			if (_frameInput)
			{
				_frameInput.text = frame.toString();
			}
			if (showPrompt)
			{
				CheatPanel.log("已设置帧率为：" + frame + "帧");
			}
		}
		
		private function onQualityTrackClick(e:MouseEvent):void
		{
			if (!_qualityTrack || !_qualityPositions)
			{
				return;
			}
			var localX:Number = _qualityTrack.mouseX;
			setQualityIndexByPosition(localX, true);
			e.stopImmediatePropagation();
		}
		
		private function onQualityKnobMouseDown(e:MouseEvent):void
		{
			if (!stage)
			{
				return;
			}
			_draggingKnob = true;
			stage.addEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
			stage.addEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
			e.stopImmediatePropagation();
		}
		
		private function onStageMouseMove(e:MouseEvent):void
		{
			if (!_draggingKnob)
			{
				return;
			}
			if (!parent)
			{
				return;
			}
			var newX:Number = this.mouseX;
			if (newX < _dragMinX)
			{
				newX = _dragMinX;
			}
			if (newX > _dragMaxX)
			{
				newX = _dragMaxX;
			}
			_qualityKnob.x = newX;
			e.updateAfterEvent();
		}
		
		private function onStageMouseUp(e:MouseEvent):void
		{
			if (!_draggingKnob)
			{
				return;
			}
			_draggingKnob = false;
			if (stage)
			{
				stage.removeEventListener(MouseEvent.MOUSE_MOVE, onStageMouseMove);
				stage.removeEventListener(MouseEvent.MOUSE_UP, onStageMouseUp);
			}
			if (_qualityTrack && _qualityPositions)
			{
				var localX:Number = _qualityKnob.x - _qualityTrack.x;
				setQualityIndexByPosition(localX, true);
			}
		}
		
		private function setQualityIndexByPosition(localX:Number, apply:Boolean):void
		{
			var idx:int = 0;
			var minDist:Number = Number.MAX_VALUE;
			var i:int = 0;
			while (i < _qualityPositions.length)
			{
				var px:Number = Number(_qualityPositions[i]);
				var d:Number = Math.abs(localX - px);
				if (d < minDist)
				{
					minDist = d;
					idx = i;
				}
				i++;
			}
			setQualityIndex(idx, apply);
		}
		
		private function setQualityIndex(index:int, apply:Boolean):void
		{
			if (index < 0)
			{
				index = 0;
			}
			if (index >= QUALITY_ORDER.length)
			{
				index = QUALITY_ORDER.length - 1;
			}
			_qualityIndex = index;
			updateQualityUI();
			if (apply)
			{
				applyQualityWithPrompt();
				saveSettingToSOL();
			}
		}
		
		private function updateQualityUI():void
		{
			if (!_qualityKnob || !_qualityTrack || !_qualityPositions)
			{
				return;
			}
			if (_qualityIndex < 0)
			{
				_qualityIndex = 0;
			}
			if (_qualityIndex >= _qualityPositions.length)
			{
				_qualityIndex = _qualityPositions.length - 1;
			}
			var px:Number = Number(_qualityPositions[_qualityIndex]);
			_qualityKnob.x = _qualityTrack.x + px;
			if (_qualityInfoLabel)
			{
				var nameStr:String = QUALITY_NAME[_qualityIndex];
				var aaStr:String = QUALITY_AA[_qualityIndex];
				var scaleStr:String = QUALITY_SCALE[_qualityIndex];
				_qualityInfoLabel.text = nameStr + " " + aaStr + " " + scaleStr;
			}
		}
		
		private function applyQualityWithPrompt():void
		{
			if (!curStage)
			{
				return;
			}
			var q:String = QUALITY_ORDER[_qualityIndex];
			curStage.quality = q;
			var nameStr:String = QUALITY_NAME[_qualityIndex];
			CheatPanel.log("画质已设置为：" + nameStr);
		}
		
		private function mapStageQualityToIndex(q:String):int
		{
			var i:int = 0;
			while (i < QUALITY_ORDER.length)
			{
				if (QUALITY_ORDER[i] == q)
				{
					return i;
				}
				i++;
			}
			return 1;
		}
		
		private function loadSettingFromSOL():void
		{
			var q:String;
			var nameStr:String;
			try
			{
				_so = SharedObject.getLocal(SOL_NAME);
				if (_so.data.hasOwnProperty("frameRate"))
				{
					_frameRate = int(_so.data.frameRate);
				}
				else if (_so.data.hasOwnProperty("frame60"))
				{
					_frameRate = Boolean(_so.data.frame60) ? 60 : 29;
				}
				else if (curStage)
				{
					_frameRate = curStage.frameRate;
				}
				else
				{
					_frameRate = 29;
				}
				if (_so.data.hasOwnProperty("qualityIndex"))
				{
					_qualityIndex = int(_so.data.qualityIndex);
				}
				else if (curStage)
				{
					_qualityIndex = mapStageQualityToIndex(curStage.quality);
				}
				else
				{
					_qualityIndex = 1;
				}
			}
			catch (e:Error)
			{
				if (curStage)
				{
					_frameRate = curStage.frameRate;
					_qualityIndex = mapStageQualityToIndex(curStage.quality);
				}
				else
				{
					_frameRate = 29;
					_qualityIndex = 1;
				}
			}
			applyFrameRate(_frameRate, _frameRate != 29);
			if (curStage)
			{
				q = QUALITY_ORDER[_qualityIndex];
				curStage.quality = q;
				if (q != StageQuality.MEDIUM)
				{
					nameStr = QUALITY_NAME[_qualityIndex];
					CheatPanel.log("画质已设置为：" + nameStr);
				}
			}
		}
		
		private function saveSettingToSOL():void
		{
			try
			{
				if (!_so)
				{
					_so = SharedObject.getLocal(SOL_NAME);
				}
				_so.data.frameRate = _frameRate;
				_so.data.qualityIndex = _qualityIndex;
				_so.flush();
			}
			catch (e:Error)
			{
			}
		}
	}
}

