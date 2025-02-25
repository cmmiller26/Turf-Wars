import { Component } from "@flamework/components";
import { OnRender } from "@flamework/core";
import { RunService, TextChatService, UserInputService } from "@rbxts/services";
import Signal from "@rbxts/signal";
import { ViewmodelComponent } from "client/components/characters/addons";
import { HammerComponent, SlingshotComponent, ToolComponent } from "client/components/tools";
import { Events } from "client/network";
import { R15GameCharacterInstance, R6GameCharacterInstance } from "shared/types/characterTypes";
import { ToolType } from "shared/types/toolTypes";
import { findFirstChildWithTag } from "shared/utility";
import { CharacterComponent } from "./CharacterComponent";

@Component()
export class GameCharacterComponent extends CharacterComponent implements OnRender {
	protected override CAMERA_MODE = Enum.CameraMode.LockFirstPerson;

	public ToolEquipped: Signal<(slot: number) => void> = new Signal();

	public get combatEnabled(): boolean {
		return this._combatEnabled;
	}
	public set combatEnabled(value: boolean) {
		print(`Combat enabled: ${value}`);
		this._combatEnabled = value;
	}
	private _combatEnabled: boolean = false;

	public get tools(): Array<ToolComponent> {
		return this._tools;
	}
	public get curTool(): ToolComponent {
		return this._curTool;
	}
	private set curTool(value: ToolComponent) {
		this._curTool = value;
	}
	private _tools: Array<ToolComponent> = [];
	private _curTool!: ToolComponent;

	private chatInputBarConfig?: ChatInputBarConfiguration;

	private toolJoint!: Motor6D;

	private viewmodel!: ViewmodelComponent;

	public override onStart(): void {
		super.onStart();

		this.fetchChatInputBarConfig();

		this.constructViewmodel();
		this.constructTools();

		task.spawn(async () => {
			await this.attachToolJointToViewmodel();
			this.equipTool(0);
		});

		this.janitor.Add(this.ToolEquipped);
	}

	public override onTick(dt: number): void {
		super.onTick(dt);

		UserInputService.MouseBehavior = this.chatInputBarConfig?.IsFocused
			? Enum.MouseBehavior.Default
			: Enum.MouseBehavior.LockCenter;
	}

	public onRender(): void {
		if (!this.curTool) return;

		this.curTool.instance
			.GetDescendants()
			.filter((descendant) => descendant.IsA("BasePart"))
			.forEach((part) => {
				part.CastShadow = false;
				part.LocalTransparencyModifier = 0;
			});
	}

	public equipTool(slot: number): void {
		if (!this.isAlive) return;

		const newTool = this.tools[slot];
		if (!newTool) {
			warn(`No tool found in slot ${slot}`);
			return;
		}

		if (newTool === this.curTool) return;
		this.unequip();

		this.curTool = newTool;
		this.curTool.equip();

		/**
		 * Attach the tool to the character after the next animation frame.
		 * This ensures the tool doesn't appear before the equip animation starts.
		 */
		task.spawn(() => {
			RunService.PreAnimation.Wait();
			if (this.curTool) {
				this.toolJoint.Part1 = this.curTool.instance.PrimaryPart;
				this.curTool.instance.Parent = this.instance;
			}
		});

		this.ToolEquipped.Fire(slot);
		Events.EquipTool.fire(this.curTool.toolType);

		print(`Equipped ${this.curTool.instance.Name}`);
	}

	public cycleTool(direction: number): void {
		if (this.tools.size() === 0) return;

		const curIndex = this.curTool ? this.tools.indexOf(this.curTool) : -1;
		const nextIndex = (curIndex + direction + this.tools.size()) % this.tools.size();
		this.equipTool(nextIndex);
	}

	public unequip(): boolean {
		if (!this.curTool) return true;

		this.curTool.unequip();

		this.curTool.instance.Parent = this.controller.backpack;
		this.toolJoint.Part1 = undefined;

		return true;
	}

	private fetchChatInputBarConfig(): void {
		this.chatInputBarConfig = TextChatService.FindFirstChildOfClass("ChatInputBarConfiguration");
		if (!this.chatInputBarConfig) warn("Chat input bar configuration not found");
	}

	private fetchToolJoint(): void {
		this.toolJoint =
			this.instance.Humanoid.RigType === Enum.HumanoidRigType.R6
				? (this.instance as R6GameCharacterInstance).Torso.ToolJoint
				: (this.instance as R15GameCharacterInstance).UpperTorso.ToolJoint;
	}

	private constructViewmodel(): void {
		print("Constructing viewmodel component...");

		this.viewmodel = this.components.addComponent<ViewmodelComponent>(this.instance);
		this.janitor.Add(() => {
			this.components.removeComponent<ViewmodelComponent>(this.instance);
		});

		print("Viewmodel component constructed");
	}

	private constructTools(): void {
		const hammer = findFirstChildWithTag(this.controller.backpack, ToolType.Hammer);
		const slingshot = findFirstChildWithTag(this.controller.backpack, ToolType.Slingshot);
		if (!hammer || !slingshot) error("Missing tool instances in backpack");

		print("Constructing tool components...");

		this.tools.push(this.components.addComponent<SlingshotComponent>(slingshot));
		this.tools.push(this.components.addComponent<HammerComponent>(hammer));
		this.tools.forEach((tool) => tool.initialize(this, this.viewmodel));

		this.janitor.Add(() => {
			this.unequip();
			this.tools.clear();

			this.components.removeComponent<HammerComponent>(hammer);
			this.components.removeComponent<SlingshotComponent>(slingshot);
		});

		print("Tool components constructed");
	}

	private async attachToolJointToViewmodel(): Promise<void> {
		try {
			const viewmodelInstance = await this.viewmodel.waitForViewmodel();

			this.fetchToolJoint();
			this.toolJoint.Part0 = viewmodelInstance.Torso;
			this.toolJoint.Parent = viewmodelInstance.Torso;
		} catch {
			error("Failed to attach tool joint to viewmodel");
		}
	}
}
