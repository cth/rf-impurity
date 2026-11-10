from shiny import App, ui, render, reactive
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.inspection import permutation_importance
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def make_linear(n, seed=1):
    rng = np.random.default_rng(seed)
    a = rng.uniform(0, 1, n)
    b = rng.uniform(0, 1, n)
    c = rng.uniform(0, 1, n)
    y = a + 2 * b + 4 * c
    X = pd.DataFrame({"a": a, "b": b, "c": c})
    return X, y


def make_parity(n, seed=1):
    rng = np.random.default_rng(seed)
    a = rng.integers(0, 2, n)
    b = rng.integers(0, 2, n)
    c = rng.integers(0, 2, n)
    y = ((a + b) % 2) + 0.5 * c
    X = pd.DataFrame({"a": a.astype(float), "b": b.astype(float), "c": c.astype(float)})
    return X, y


def make_nonlinear(n, seed=1):
    rng = np.random.default_rng(seed)
    a = rng.uniform(-1, 1, n)
    b = rng.uniform(-1, 1, n)
    c = rng.uniform(-1, 1, n)
    y = a + b ** 3 + np.sin(2 * np.pi * c)
    X = pd.DataFrame({"a": a, "b": b, "c": c})
    return X, y


def make_confound(n, seed=1):
    rng = np.random.default_rng(seed)
    # World 1: linear effect on skewed feature
    x1 = rng.exponential(1, n)
    y1 = 2 * x1
    # World 2: nonlinear effect on uniform feature with same variance contribution
    x2 = rng.uniform(0, np.sqrt(12) * np.std(x1), n)  # match sd roughly
    # adjust to same variance contribution: Var(f)=4 Var(x1) for world1
    # choose f2 = 4*sin? We'll just use quadratic with matched variance
    f2 = x2 ** 2 - np.mean(x2 ** 2)
    f2 = f2 / np.std(f2) * (2 * np.std(x1))
    y2 = f2
    X1 = pd.DataFrame({"x": x1})
    X2 = pd.DataFrame({"x": x2})
    return X1, y1, X2, y2


def rf_importances(X, y, max_features, n_estimators, max_depth, seed=1):
    rf = RandomForestRegressor(
        n_estimators=n_estimators,
        max_features=max_features,
        max_depth=None if max_depth == 0 else max_depth,
        random_state=seed,
        n_jobs=1,
    )
    rf.fit(X, y)
    mdi = rf.feature_importances_
    perm = permutation_importance(rf, X, y, n_repeats=5, random_state=seed, n_jobs=1)
    return mdi, perm.importances_mean


def plot_bars(labels, mdi, perm, title):
    fig, ax = plt.subplots(figsize=(6, 3.5))
    x = np.arange(len(labels))
    w = 0.35
    ax.bar(x - w / 2, mdi, w, label="MDI")
    ax.bar(x + w / 2, perm, w, label="Permutation")
    ax.set_xticks(x)
    ax.set_xticklabels(labels)
    ax.set_title(title)
    ax.legend()
    fig.tight_layout()
    return fig


app_ui = ui.page_fluid(
    ui.h2("RF impurity importance: interactive companion"),
    ui.navset_tab(
        ui.nav_panel("Linear effects",
            ui.layout_sidebar(
                ui.sidebar(
                    ui.input_slider("lin_n", "n", 200, 2000, 1000, step=200),
                    ui.input_slider("lin_trees", "trees", 50, 300, 100, step=50),
                    ui.input_slider("lin_mf", "max_features (mtry)", 1, 3, 1),
                    ui.input_slider("lin_depth", "max_depth (0=unlimited)", 0, 12, 0, step=1),
                    ui.input_action_button("lin_run", "Run"),
                ),
                ui.output_plot("lin_plot"),
                ui.output_text_verbatim("lin_text"),
            ),
        ),
        ui.nav_panel("Interactions (parity)",
            ui.layout_sidebar(
                ui.sidebar(
                    ui.input_slider("par_n", "n", 500, 5000, 2000, step=500),
                    ui.input_slider("par_trees", "trees", 50, 300, 100, step=50),
                    ui.input_slider("par_mf", "max_features", 1, 3, 2),
                    ui.input_action_button("par_run", "Run"),
                ),
                ui.output_plot("par_plot"),
                ui.output_text_verbatim("par_text"),
            ),
        ),
        ui.nav_panel("Nonlinear terms",
            ui.layout_sidebar(
                ui.sidebar(
                    ui.input_slider("nl_n", "n", 500, 3000, 1000, step=500),
                    ui.input_slider("nl_trees", "trees", 50, 300, 100, step=50),
                    ui.input_action_button("nl_run", "Run"),
                ),
                ui.output_plot("nl_plot"),
                ui.output_text_verbatim("nl_text"),
            ),
        ),
        ui.nav_panel("Confound (shape vs spread)",
            ui.layout_sidebar(
                ui.sidebar(
                    ui.input_slider("cf_n", "n", 500, 3000, 1000, step=500),
                    ui.input_slider("cf_trees", "trees", 50, 300, 100, step=50),
                    ui.input_action_button("cf_run", "Run"),
                ),
                ui.output_plot("cf_plot"),
                ui.output_text_verbatim("cf_text"),
            ),
        ),
    ),
)


def server(input, output, session):
    @reactive.event(input.lin_run)
    def lin_res():
        X, y = make_linear(input.lin_n(), seed=1)
        mdi, perm = rf_importances(X, y, input.lin_mf(), input.lin_trees(), input.lin_depth())
        return X.columns.tolist(), mdi, perm

    @render.plot
    def lin_plot():
        r = lin_res()
        if r is None:
            return
        labels, mdi, perm = r
        return plot_bars(labels, mdi, perm, "Linear effects: y = a + 2b + 4c")

    @render.text
    def lin_text():
        r = lin_res()
        if r is None:
            return "Click Run"
        labels, mdi, perm = r
        return "MDI ratios: " + "  ".join(f"{l}={v:.2f}" for l, v in zip(labels, mdi / mdi[0])) + \
               "\nPerm ratios: " + "  ".join(f"{l}={v:.2f}" for l, v in zip(labels, perm / perm[0]))

    @reactive.event(input.par_run)
    def par_res():
        X, y = make_parity(input.par_n(), seed=1)
        mdi, perm = rf_importances(X, y, input.par_mf(), input.par_trees(), 0)
        return X.columns.tolist(), mdi, perm

    @render.plot
    def par_plot():
        r = par_res()
        if r is None:
            return
        labels, mdi, perm = r
        return plot_bars(labels, mdi, perm, "Parity interaction: y=(a+b) mod 2 + 0.5 c")

    @render.text
    def par_text():
        r = par_res()
        if r is None:
            return "Click Run"
        labels, mdi, perm = r
        return "MDI: " + "  ".join(f"{l}={v:.3f}" for l, v in zip(labels, mdi)) + \
               "\nPerm: " + "  ".join(f"{l}={v:.3f}" for l, v in zip(labels, perm))

    @reactive.event(input.nl_run)
    def nl_res():
        X, y = make_nonlinear(input.nl_n(), seed=1)
        mdi, perm = rf_importances(X, y, 3, input.nl_trees(), 0)
        return X.columns.tolist(), mdi, perm

    @render.plot
    def nl_plot():
        r = nl_res()
        if r is None:
            return
        labels, mdi, perm = r
        return plot_bars(labels, mdi, perm, "Nonlinear terms: y = a + b^3 + sin(2pi c)")

    @render.text
    def nl_text():
        r = nl_res()
        if r is None:
            return "Click Run"
        labels, mdi, perm = r
        return "MDI: " + "  ".join(f"{l}={v:.3f}" for l, v in zip(labels, mdi)) + \
               "\nPerm: " + "  ".join(f"{l}={v:.3f}" for l, v in zip(labels, perm))

    @reactive.event(input.cf_run)
    def cf_res():
        X1, y1, X2, y2 = make_confound(input.cf_n(), seed=1)
        mdi1, perm1 = rf_importances(X1, y1, 1, input.cf_trees(), 0)
        mdi2, perm2 = rf_importances(X2, y2, 1, input.cf_trees(), 0)
        return mdi1[0], perm1[0], mdi2[0], perm2[0]

    @render.plot
    def cf_plot():
        r = cf_res()
        if r is None:
            return
        mdi1, perm1, mdi2, perm2 = r
        fig, ax = plt.subplots(figsize=(6, 3.5))
        ax.bar([0, 1], [mdi1, mdi2], 0.35, label="MDI")
        ax.bar([0.4, 1.4], [perm1, perm2], 0.35, label="Permutation")
        ax.set_xticks([0.2, 1.2])
        ax.set_xticklabels(["World 1 (linear, skewed)", "World 2 (nonlinear, uniform)"])
        ax.set_title("Confound: similar importance, different shape")
        ax.legend()
        fig.tight_layout()
        return fig

    @render.text
    def cf_text():
        r = cf_res()
        if r is None:
            return "Click Run"
        mdi1, perm1, mdi2, perm2 = r
        return (f"World1 MDI={mdi1:.3f} perm={perm1:.3f}\n"
                f"World2 MDI={mdi2:.3f} perm={perm2:.3f}")


app = App(app_ui, server)
PY
mkdir -p /home/cth/code/cth/rf-impurity/companion
cp /tmp/opencode/shinytest/app.py /dev/null 2>/dev/null
cp /home/cth/code/cth/rf-impurity/.git/HEAD /dev/null 2>/dev/null
mkdir -p /home/cth/code/cth/rf-impurity/companion
mv /tmp/opencode/shinytest/app.py /home/cth/code/cth/rf-impurity/companion/app.py 2>/dev/null || true