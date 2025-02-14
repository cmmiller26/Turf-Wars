import { Flamework, OnStart, Service } from "@flamework/core";
import { Players, RunService, ServerStorage, Teams, Workspace } from "@rbxts/services";
import { Events } from "server/network";
import { CharacterType } from "shared/types/characterTypes";
import { GameMap } from "shared/types/workspaceTypes";
import { BlockGrid } from "shared/modules";
import { PlayerRegistry, TurfService } from ".";

enum GameState {
	WaitingForPlayers = "Waiting for Players",
	Intermission = "Intermission",
	PreRound = "Pre-round",
	InRound = "In Round",
	PostRound = "Post-round",
}

type Phase = {
	Type: PhaseType;
	Duration: number;
	TurfPerKill?: number;
};
enum PhaseType {
	Build = "Build",
	Combat = "Combat",
}

const isGameMap = Flamework.createGuard<GameMap>();

function fisherYatesShuffle<T>(array: T[]): T[] {
	const shuffled = [...array];
	for (let i = shuffled.size() - 1; i > 0; i--) {
		const j = math.floor(math.random() * (i + 1));
		[shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
	}
	return shuffled;
}

@Service()
export class RoundManager implements OnStart {
	private readonly MIN_PLAYER_COUNT: number = 2;

	private readonly INTERMISSION_TIME: number = 60;
	private readonly ROUND_START_COUNTDOWN: number = 10;

	private readonly PHASE_SEQUENCE: Phase[] = [
		{ Type: PhaseType.Build, Duration: 40 },
		{ Type: PhaseType.Combat, Duration: 90 },
		{ Type: PhaseType.Build, Duration: 20 },
		{ Type: PhaseType.Combat, Duration: 90, TurfPerKill: 3 },
	];

	private readonly SPECTATOR_TEAM: Team = Teams.FindFirstChild("Spectators") as Team;

	private readonly GAME_MAP_PREFAB: GameMap;
	private readonly MAP_LOAD_TIMEOUT: number = 10;

	public get state(): GameState {
		return this._state;
	}
	private set state(value: GameState) {
		this._state = value;
	}
	private _state: GameState = GameState.WaitingForPlayers;

	private phaseIndex: number = 0;
	private cancelTimer?: () => boolean;

	private players: Set<Player> = new Set();

	private team1: Team = Teams.FindFirstChild("Blue Team") as Team;
	private team2: Team = Teams.FindFirstChild("Red Team") as Team;

	private prevGameMap?: GameMap;

	public constructor(private playerRegistry: PlayerRegistry, private turfService: TurfService) {
		const map = ServerStorage.FindFirstChild("Map");
		if (!map || !isGameMap(map)) error("No valid map found in server storage");
		this.GAME_MAP_PREFAB = map;

		if (RunService.IsStudio()) {
			this.MIN_PLAYER_COUNT = 1;
			this.INTERMISSION_TIME = 2;
			this.ROUND_START_COUNTDOWN = 2;
			this.PHASE_SEQUENCE = [{ Type: PhaseType.Combat, Duration: 60 }];
		}
	}

	public onStart(): void {
		Players.PlayerAdded.Connect(() => this.onPlayerAdded());
		Players.PlayerRemoving.Connect((player) => this.onPlayerRemoving(player));
	}

	private async startIntermission(): Promise<void> {
		this.changeState(GameState.Intermission);
		await this.promiseTimer(this.INTERMISSION_TIME);
		await this.startRound();
	}

	private async startRound(): Promise<void> {
		if (this.state !== GameState.Intermission) return;

		this.changeState(GameState.PreRound);

		print("Loading game map...");

		const gameMap = await this.loadGameMap().catch((err) => {
			warn(`Failed to load game map: ${err}`);
			this.changeState(GameState.WaitingForPlayers);
			this.checkPlayerCount();
			return undefined;
		});
		if (!gameMap) return;

		this.prevGameMap?.Destroy();
		this.prevGameMap = gameMap;

		print("Game map loaded");

		this.turfService.initialize(this.team1, this.team2, gameMap);

		Players.GetPlayers().forEach((player) => this.players.add(player));
		this.shuffleTeams();
		await this.setPlayerComponents(CharacterType.Game);

		Events.RoundStarting.broadcast(this.team1, this.team2);

		await Promise.delay(this.ROUND_START_COUNTDOWN);

		this.changeState(GameState.InRound);
		this.disableSpawnBarriers(gameMap);

		await this.runPhase(0);
	}

	private async runPhase(index: number): Promise<void> {
		if (this.state !== GameState.InRound) return;

		if (index >= this.PHASE_SEQUENCE.size()) {
			await this.endRound();
			return;
		}

		this.phaseIndex = index;
		const phase = this.PHASE_SEQUENCE[this.phaseIndex];

		const isCombat = phase.Type === PhaseType.Combat;
		if (isCombat) {
			this.turfService.setTurfPerKill(phase.TurfPerKill ?? 1);
		}
		this.playerRegistry.setCombatEnabled(isCombat);

		print(`Starting ${phase.Type} phase ${index + 1}`);

		await this.promiseTimer(phase.Duration);
		await this.runPhase(index + 1);
	}

	private async endRound(): Promise<void> {
		if (this.state !== GameState.InRound) return;

		this.changeState(GameState.PostRound);

		this.players.forEach((player) => (player.Team = this.SPECTATOR_TEAM));
		await this.setPlayerComponents(CharacterType.Lobby);
		this.players.clear();

		this.checkPlayerCount();
	}

	private changeState(newState: GameState): void {
		if (this.state === newState) return;

		if (this.cancelTimer) {
			this.cancelTimer();
			this.cancelTimer = undefined;
		}

		print(`Changing state to ${newState}`);

		this.state = newState;
	}

	private isMapReady(map: GameMap): boolean {
		return (
			map.TurfLines !== undefined &&
			map.Team1Spawn !== undefined &&
			map.Team2Spawn !== undefined &&
			map.TurfLines.GetChildren().size() >= BlockGrid.DIMENSIONS.X &&
			map.Team1Spawn.SpawnBarriers !== undefined &&
			map.Team1Spawn.SpawnLocations !== undefined &&
			map.Team2Spawn.SpawnBarriers !== undefined &&
			map.Team2Spawn.SpawnLocations !== undefined
		);
	}

	private async loadGameMap(): Promise<GameMap> {
		return new Promise((resolve, reject) => {
			const map = this.GAME_MAP_PREFAB.Clone();
			map.Parent = Workspace;

			const start = os.clock();
			while (os.clock() - start < this.MAP_LOAD_TIMEOUT) {
				if (this.isMapReady(map)) {
					resolve(map);
					return;
				}
				task.wait(0.1);
			}

			map.Destroy();
			reject("Map load timeout");
		});
	}

	private disableSpawnBarriers(map: GameMap): void {
		map.Team1Spawn.SpawnBarriers.GetChildren()
			.filter((child) => child.IsA("BasePart"))
			.forEach((barrier) => (barrier.CanCollide = false));
		map.Team2Spawn.SpawnBarriers.GetChildren()
			.filter((child) => child.IsA("BasePart"))
			.forEach((barrier) => (barrier.CanCollide = false));
	}

	private async setPlayerComponents(characterType: CharacterType): Promise<void> {
		await Promise.all(
			[...this.players].map((player) => this.playerRegistry.setPlayerComponent(player, characterType)),
		);
	}

	private shuffleTeams(): void {
		let index = 0;
		fisherYatesShuffle([...this.players]).forEach((player) => {
			player.Team = index % 2 === 0 ? this.team1 : this.team2;
			index++;
		});
	}

	private removePlayerFromRound(player: Player): void {
		this.players.delete(player);
		if (this.players.size() < this.MIN_PLAYER_COUNT) this.endRound();
	}

	private checkPlayerCount(): void {
		if (Players.GetPlayers().size() >= this.MIN_PLAYER_COUNT) {
			if (this.state === GameState.WaitingForPlayers || this.state === GameState.PostRound) {
				this.startIntermission();
			}
		} else if (this.state !== GameState.WaitingForPlayers) {
			this.changeState(GameState.WaitingForPlayers);
		}
	}

	private promiseTimer(duration: number): Promise<void> {
		let cancelled = false;
		const promise = new Promise<void>((resolve, reject) => {
			const begin = os.clock();
			while (os.clock() - begin < duration) {
				if (cancelled) {
					reject();
					return;
				}
				task.wait();
			}
			resolve();
		});

		this.cancelTimer = (): boolean => (cancelled = true);

		return promise;
	}

	private onPlayerAdded(): void {
		if (this.state === GameState.WaitingForPlayers) this.checkPlayerCount();
	}
	private onPlayerRemoving(player: Player): void {
		if (this.state === GameState.PreRound || this.state === GameState.InRound) {
			this.removePlayerFromRound(player);
		} else {
			this.checkPlayerCount();
		}
	}
}
