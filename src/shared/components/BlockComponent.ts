import { BaseComponent, Component } from "@flamework/components";
import { OnStart } from "@flamework/core";

interface Attributes {
	Health: number;
	TeamColor: BrickColor;
}

@Component({
	tag: "Block",
})
class BlockComponent extends BaseComponent<Attributes, BasePart> implements OnStart {
	private readonly MAX_HEALTH: number = 100;

	public onStart(): void {
		this.attributes.Health = this.MAX_HEALTH;
		this.instance.BrickColor = this.attributes.TeamColor;
	}

	public takeDamage(damage: number): boolean {
		this.attributes.Health -= damage;

		if (this.attributes.Health <= 0) {
			this.instance.Destroy();
			return true;
		}

		this.instance.Transparency = 0.5 * (1 - this.attributes.Health / this.MAX_HEALTH);
		return false;
	}
}

export default BlockComponent;
