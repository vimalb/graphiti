#! /usr/bin/Rscript

# Veritabill 1.0.0, June 11, 2012
# Copyright (c) 2012 Prior Knowledge, Inc.
# Questions? Contact Max Gasner <max@priorknowledge.com>.
#
# This R script generates synthetic data (/scripts/seed_data.csv) with which
# to seed our application database.
#
# We assume that there are two classes of task, "Long" and "Short". Long tasks
# take an unknown amount of time, but are normally distributed with a mean of
# 48 work hours and standard deviation of 8 hours. Short tasks take an unknown
# amount of time, normally distributed with a mean of 4 work hours and
# variance of 2 hours. Most tasks (80%) are short.
#
# Our users must therefore first guess what kind of task they're presented with,
# and then guess the amount of time the task will take. The best possible user
# will guess the task class correctly all of the time, and then draw randomly
# from the appropriate distribution.
#
# Our users are all pros -- it takes them the same amount of time to complete
# tasks -- but they aren't all equally good at estimating the time tasks will
# take. Sometimes they mistake short tasks for long tasks, and vice versa --
# about 5% of the time. Some of them are optimists, some of them are pessimists,
# and some of them are less realistic about the range of time tasks can take. 

users <- list(
  # Yvette is a pessimist; she thinks tasks will take twice as long as they
  # really do.
  Yvette = list(
    estimate = c(2, 1) # 2x the true mean
  ),
  # Tom often mistakes short tasks for long tasks -- about three times as
  # often as his coworkers.
  Tom = list(
    misclassify = c(3, 1) # 3x misclassification rate on short tasks, 1x on long
  ),
  # Jim is an optimist at the start of his work day, and a pessimist at the
  # end of the day.
  Jim = list(
    morning.estimate = c(0.75, 0.75), # lower mean and variance
    afternoon.estimate = c(1.5, 1.5) # higher mean and variance
  ),
  # Cindy's estimates have a lot of variance.
  Cindy = list(
    estimate = c(1, 2) # 2x the true variance
  ),
  # Evelyn overestimates the time harder tasks will take, and underestimates
  # the time shorter tasks will take. 
  Evelyn = list(
    short.estimate = c(0.5, 1), # half the true mean
    long.estimate = c(2, 1) # twice the true mean
  )
)

# Users estimate the time tasks will take at different times. They each
# perform tasks for all of the firm's clients.
days <- c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
times <- c("Morning", "Lunchtime", "Afternoon")
clients <- c("OCP Inc", "Cyberdyne Systems", "Weyland-Yutani", "Tyrell",
  "Mooby's Family Restaurants")

# We seed the time tracker with 1000 tasks. About 80% of the tasks are short.
n <- 1000
short.tasks <- 0.8
task.class <- replicate(n, if (runif(1) < short.tasks) "Short" else "Long")

# We measure tasks in units of 30 minutes; no task takes less than 30 minutes.
# Users misclassify about 5% of tasks.

misclassify <- 0.05
tasks <- data.frame(
  class = task.class,
  user = sample(names(users), n, replace = TRUE), # pick the user at random
  day = sample(days, n, replace = TRUE), # pick the day of the week at random
  time_of_day = sample(times, n, replace = TRUE), # pick the time of day at random
  client = sample(clients, n, replace = TRUE), # pick the client at random
  true_time = sapply(task.class, function (t) { # true generative process
    max(1, if (t == "Short") round(rnorm(1, 8, 4)) else round(rnorm(1, 96, 16)))})
)

tasks <- cbind(tasks, user_class = sapply(1:(dim(tasks)[1]), function (i) {
  t <- tasks[i, "class"]
  u <- users[tasks[i, "user"]]
  misclassify <- misclassify * (if ('misclassify' %in% u) u['misclassify'] else 1)
  if (runif(1) < misclassify) {
    if (t == "Short") "Long" else "Short"
  } else {
    as.character(t)
  }
}))

tasks <- cbind(tasks, user_estimate = sapply(1:(dim(tasks)[1]), function (i) {
  t <- tasks[i, "class"]
  u <- users[tasks[i, "user"]]
  time <- tasks[i, "time_of_day"]

  # misclassification rate
  misclassify <- misclassify * (if ('misclassify' %in% u) u['misclassify'] else 1)
  if (runif(1) < misclassify) {
    t <- (if (t == "Short") "Long" else "Short")
  }

  params <- if (t == "Short") c(8, 4) else c(96, 16)

  # adjust for user biases
  params <- params * (if ('estimate' %in% u) u['estimate'] else 1)

  if (time == "morning") {
    params <- params * (if ('morning.estimate' %in% u) u['morning.estimate'] else 1) 
  } else if (time == "afternoon") {
    params <- params * (if ('afternoon.estimate' %in% u) u['afternoon.estimate'] else 1)
  }
  if (t == "Short") {
    params <- params * (if ('short.estimate' %in% u) u['short.estimate'] else 1)
  } else {
    params <- params * (if ('long.estimate' %in% u) u['long.estimate'] else 1)
  }

  estimate <- max(1, round(rnorm(1, params[1], params[2])))
  estimate
}))

write.csv(tasks, "seed_data.csv", row.names = FALSE)
