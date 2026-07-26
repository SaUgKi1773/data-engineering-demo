<script>
  // Champions-League-style bracket for the liguilla, fed one row per TIE by
  // mart_liguilla_bracket.
  //
  // The bracket shape is NOT fixed. Between 2020/21 and 2022/23 the liguilla
  // opened with a four-match repechaje; from 2023/24 it is a two-stage
  // play-in; and Clausura 2025/26 has no play-in fixtures in the data at all.
  // So rounds are derived from whatever the tournament actually contains
  // rather than assumed, and a missing round simply means one fewer column.
  export let data = [];

  const ROUND_LABEL = {
    1: 'Play-in',
    2: 'Play-in · final place',
    3: 'Quarter-finals',
    4: 'Semi-finals',
    5: 'Final'
  };

  $: ties = Array.from(data ?? []);

  $: rounds = [...new Set(ties.map((t) => Number(t.round_order)))]
    .sort((a, b) => a - b)
    .map((order) => ({
      order,
      label: ROUND_LABEL[order] ?? '',
      ties: ties
        .filter((t) => Number(t.round_order) === order)
        .sort((a, b) => Number(a.team_a_seed) - Number(b.team_a_seed))
    }));

  // Penalties are only worth showing on the tie they actually settled.
  const pens = (t) => t.decided_by === 'Penalties';
  const sides = (t) => [
    {
      seed: t.team_a_seed,
      name: t.team_a_short ?? t.team_a_name,
      logo: t.team_a_logo,
      goals: t.team_a_goals,
      pens: t.team_a_pens,
      won: t.winner_side === 'A'
    },
    {
      seed: t.team_b_seed,
      name: t.team_b_short ?? t.team_b_name,
      logo: t.team_b_logo,
      goals: t.team_b_goals,
      pens: t.team_b_pens,
      won: t.winner_side === 'B'
    }
  ];
</script>

{#if rounds.length === 0}
  <!-- The section always renders. A tournament still in its regular rounds
       has no bracket yet, and saying so is more use than an absent panel. -->
  <div class="empty">The liguilla has not been played yet for this tournament.</div>
{:else}
  <div class="bracket-scroll">
    <div class="bracket">
      {#each rounds as round}
        <div class="round">
          <div class="round-head">{round.label}</div>
          <div class="round-body">
            {#each round.ties as tie}
              <div class="tie" class:is-final={round.order === 5}>
                {#each sides(tie) as side}
                  <div class="side" class:won={side.won} class:lost={!side.won}>
                    <span class="seed">{side.seed <= 18 ? side.seed : '–'}</span>
                    {#if side.logo}
                      <img src={side.logo} alt="" onerror="this.style.display='none'" />
                    {/if}
                    <span class="name">{side.name}</span>
                    <span class="score">
                      {side.goals}{#if pens(tie)}<span class="pens">({side.pens})</span>{/if}
                    </span>
                  </div>
                {/each}
                <div class="note">
                  {#if tie.decided_by === 'Seeding'}
                    level — higher seed advanced
                  {:else if tie.decided_by === 'Penalties'}
                    penalties
                  {:else if tie.decided_by === 'Aggregate'}
                    on aggregate
                  {:else}
                    {tie.decided_by?.toLowerCase()}
                  {/if}
                </div>
              </div>
            {/each}
          </div>
        </div>
      {/each}
    </div>
  </div>
{/if}

<style>
  .empty {
    border: 1px dashed #e5e7eb;
    border-radius: 0.6rem;
    padding: 1.25rem;
    text-align: center;
    font-size: 0.8125rem;
    color: #9ca3af;
    margin-bottom: 1.5rem;
  }
  .bracket-scroll {
    overflow-x: auto;
    padding-bottom: 0.5rem;
    margin-bottom: 1.5rem;
  }
  .bracket {
    display: flex;
    align-items: stretch;
    gap: 1.75rem;
    min-width: min-content;
  }
  .round {
    display: flex;
    flex-direction: column;
    min-width: 190px;
    flex: 1 0 190px;
  }
  .round-head {
    font-size: 0.6875rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    color: #9ca3af;
    padding-bottom: 0.5rem;
    margin-bottom: 0.75rem;
    border-bottom: 1px solid #e5e7eb;
    text-align: center;
  }
  /* Ties spread evenly down the column, so each later round sits centred
     against the pair that fed it — the branching read of a bracket without
     pretending to a perfect binary tree the play-in rounds never form. */
  .round-body {
    display: flex;
    flex-direction: column;
    justify-content: space-around;
    gap: 0.75rem;
    flex: 1;
  }
  .tie {
    position: relative;
    border: 1px solid #e5e7eb;
    border-radius: 0.6rem;
    background: #fff;
    box-shadow: 0 1px 2px rgb(0 0 0 / 0.04);
    overflow: hidden;
  }
  .tie.is-final {
    border-color: #fcd34d;
    box-shadow: 0 1px 3px rgb(217 119 6 / 0.18);
  }
  /* connector stub linking a tie to the next round */
  .round:not(:last-child) .tie::after {
    content: '';
    position: absolute;
    top: 50%;
    right: -1.75rem;
    width: 1.75rem;
    border-top: 1px solid #e5e7eb;
  }
  .side {
    display: flex;
    align-items: center;
    gap: 0.4rem;
    padding: 0.35rem 0.5rem;
    font-size: 0.8125rem;
  }
  .side + .side {
    border-top: 1px solid #f3f4f6;
  }
  .side.won {
    font-weight: 600;
    color: #111827;
  }
  .side.lost {
    color: #9ca3af;
  }
  .side.won .score {
    color: #047857;
  }
  .seed {
    flex: 0 0 1rem;
    font-size: 0.625rem;
    color: #9ca3af;
    text-align: center;
  }
  .side img {
    height: 16px;
    width: 16px;
    object-fit: contain;
    flex-shrink: 0;
  }
  .side.lost img {
    opacity: 0.55;
  }
  .name {
    flex: 1;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .score {
    font-variant-numeric: tabular-nums;
    flex-shrink: 0;
  }
  .pens {
    font-size: 0.625rem;
    color: #6b7280;
    margin-left: 0.15rem;
  }
  .note {
    padding: 0.2rem 0.5rem 0.3rem;
    font-size: 0.625rem;
    color: #9ca3af;
    background: #fafafa;
    border-top: 1px solid #f3f4f6;
  }

  /* Phones: one round per row, stacked. */
  @media (max-width: 640px) {
    .bracket {
      flex-direction: column;
      gap: 1.25rem;
    }
    .round {
      min-width: 0;
    }
    .round-body {
      gap: 0.5rem;
    }
    .round:not(:last-child) .tie::after {
      display: none;
    }
  }
</style>
