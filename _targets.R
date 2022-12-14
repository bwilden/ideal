library(targets)
library(tarchetypes)

# Loading functions
source(here::here("R", "sim_funcs.R"))
source(here::here("R", "prep_funcs.R"))
source(here::here("R", "ideal_est_funcs.R"))

options(tidyverse.quiet = TRUE)
set.seed(111)
tar_option_set(packages = c("here",
                            "tidyverse",
                            "MetBrewer",
                            "lubridate",
                            "brms",
                            "tidybayes",
                            "ggdist",
                            "bayesplot",
                            "pscl",
                            "ggstance"))
suppressWarnings(library(tidyverse))

list(
  tar_target(
    cfl_data,
    prep_cfl_data()
  ),
  # Simulations
  tar_target(
    sim_data,
    tibble(tau_mean = c(0, 1, 2, 3, 4),
           tau_rate = c(.5, .5, .5, .5, .5)) %>% 
      pmap(gen_sim_data)
  ),
  tar_target(
    ord_irt_specs,
    set_irt_formula_priors("ordinal")
  ),
  tar_target(
    ord_irt,
    pmap(tibble(input_df = map(sim_data, ~.x$ij_all),
                irt_priors = list(ord_irt_specs$irt_priors_low_tau,
                                  ord_irt_specs$irt_priors_low_tau,
                                  ord_irt_specs$irt_priors_high_tau,
                                  ord_irt_specs$irt_priors_high_tau,
                                  ord_irt_specs$irt_priors_high_tau)), 
         .f = run_brm_irt,
         irt_formula = ord_irt_specs$irt_formula,
         model_type = "ordinal",
         irt_family = ord_irt_specs$irt_family)
  ),
  tar_target(
    pscl_irt,
    map(map(sim_data, ~.x$ij_obs_rc),
        ideal,
        maxiter = 12500,
        burnin = 7500,
        dropList = list(lop = NA),
        normalize = TRUE)
  ),
  tar_target(
    sim_comparison_plots,
    pmap(tibble(ord_model = ord_irt,
                pscl_model = pscl_irt,
                true_thetas = map(sim_data, ~.x$thetas)),
         make_sim_comparison_plot)
  ),
  tar_target(
    cfl_exp_data,
    map(.x = c("110", "111", "112", "113", "114"),
        .f = expand_group_dispositions,
        groups_df = cfl_data$groups,
        n_groups = 200,
        n_bills = 600)
  ),
  tar_target(
    cfl_pscl_irt,
    map(map(cfl_exp_data, ~.x$ij_obs_rc),
        ideal,
        maxiter = 125000,
        burnin = 75000,
        dropList = list(lop = NA),
        normalize = TRUE)
  ),
  tar_target(
    cfl_ord_irt,
    map(map(cfl_exp_data, ~.x$ij_all),
        run_brm_irt,
        irt_formula = ord_irt_specs$irt_formula,
        model_type = "ordinal",
        irt_family = ord_irt_specs$irt_family,
        irt_priors = ord_irt_specs$irt_priors_high_tau)
  ),
  tar_target(
    cfl_ord_irt_checks,
    check_brms_model(cfl_ord_irt[[5]])
  ),
  tar_target(
    cfl_qis,
    calc_cfl_qis(cfl_ord_irt[[5]],
                 cfl_pscl_irt[[5]])
  ),
  tar_target(
    cfl_comparison_plot,
    map(c("ord", "pscl"),
        make_cfl_comparison_plot,
        qis = cfl_qis)
  ),
  tar_target(
    cfl_density_plot,
    make_cfl_density_plot(cfl_qis)
  ),
  tar_target(
    cfl_draws,
    calc_group_posteriors(cfl_ord_irt[[5]],
                          cfl_pscl_irt[[5]])
  ),
  tar_target(
    cfl_disagree_groups,
    make_group_posteriors_plot(cfl_draws,
                               selected_groups = c("National Employment Law Project",
                                                   "Americans for Tax Reform",
                                                   "Brennan Center for Justice",
                                                   "Sierra Club",
                                                   "Associated Builders & Contractors",
                                                   "Heritage Action for America"))
  ),
  tar_target(
    cfl_agree_groups,
    make_group_posteriors_plot(cfl_draws,
                               selected_groups = c("American Civil Liberties Union",
                                                   "United Steelworkers",
                                                   "US Chamber of Commerce",
                                                   "Center for American Progress",
                                                   "United Automobile Workers",
                                                   "AFL-CIO"))
  )
)
