import { Controller, OnStart } from "@flamework/core";
import Signal from "@rbxts/signal";
import { Events } from "client/network";
import { BlockGrid } from "shared/modules";
import { GameMap } from "shared/types/workspaceTypes";

@Controller()
export class TurfTracker implements OnStart {
	public readonly TurfChanged: Signal<() => void> = new Signal();

	private team1!: Team;
	private team2!: Team;

	private gameMap!: GameMap;

	private team1Turf: number = 0;

	public onStart(): void {
		Events.RoundStarting.connect((team1, team2, gameMap) => this.initialize(team1, team2, gameMap as GameMap));
		Events.TurfChanged.connect((team1Turf) => {
			this.team1Turf = team1Turf;
			this.TurfChanged.Fire();
		});
	}

	public initialize(team1: Team, team2: Team, gameMap: GameMap): void {
		this.team1 = team1;
		this.team2 = team2;

		this.gameMap = gameMap;

		this.team1Turf = BlockGrid.DIMENSIONS.X / 2;
	}

	public isPositionOnTurf(position: Vector3, team: Team): boolean {
		if (!BlockGrid.isPositionInBounds(position)) return false;
		return team === this.team1 ? position.X < this.getTurfDivider() : position.X >= this.getTurfDivider();
	}

	public getTeamTurf(team?: Team): number {
		return team === this.team2 ? BlockGrid.DIMENSIONS.X - this.team1Turf : this.team1Turf;
	}

	public getRaycastFilter(): Array<Instance> {
		return [BlockGrid.Folder, this.gameMap];
	}

	private getTurfDivider(): number {
		return BlockGrid.MIN_BOUNDS.X + (this.team1Turf + 0.5) * BlockGrid.BLOCK_SIZE;
	}
}
