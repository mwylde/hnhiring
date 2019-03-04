use reqwest::Client;
use reqwest::RedirectPolicy;
use serde::{Serialize, Deserialize};
use log::*;
use regex::Regex;
use regex::Captures;
use std::str::FromStr;
use lazy_static::lazy_static;
use chrono::Utc;
use chrono::Datelike;
use std::path::Path;
use std::collections::HashMap;
use std::fs;
use rayon::prelude::*;
use std::env::args;

const BASE: &str = "https://hacker-news.firebaseio.com/v0";
const USER: &str = "whoishiring";

fn main() {
    env_logger::init();
    let args: Vec<String> = args().collect();
    process(Path::new(&args[1])).unwrap();
}

#[derive(Serialize, Deserialize, Debug)]
struct User {
    about: String,
    created: u64,
    id: String,
    karma: u64,
    submitted: Vec<Id>,
}

type Id = u64;

fn default_false() -> bool { false }

#[derive(Serialize, Deserialize, Debug)]
struct Item {
    id: Id,
    #[serde(default="default_false")]
    deleted: bool,
    #[serde(rename = "type")]
    typ: String,
    by: Option<String>,
    time: u64,
    text: Option<String>,
    #[serde(default="default_false")]
    dead: bool,
    parent: Option<Id>,
    kids: Option<Vec<Id>>,
    url: Option<String>,
    score: Option<u64>,
    title: Option<String>,
    descendants: Option<u64>,
}

#[derive(Debug, PartialOrd, PartialEq, Ord, Eq, Hash, Copy, Clone)]
enum ThreadType {
    Freelancer, Fulltime
}

#[derive(Debug)]
struct Thread {
    id: Id,
    thread_type: ThreadType,
    date: Date,
    comments: Vec<Id>,
}

#[derive(Clone)]
struct ThreadListElement {
    id: Id,
    thread_type: ThreadType,
    date: Date,
}

#[derive(Debug, Ord, PartialOrd, Eq, PartialEq, Hash, Copy, Clone)]
struct Date {
    month: u32,
    year: i32,
}

impl Date {
    fn is_current(&self) -> bool {
        let now = Utc::now();
        self.month == now.month() - 1 && self.year == now.year()
    }
}

const MONTHS: [&str; 12] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

#[derive(Debug, Serialize)]
struct Comment {
    id: Id,
    level: u64,
    html: String,
    submitter: String,
    url: String,
    time: u64,
}

fn parse_type(title: &str) -> Option<ThreadType> {
    if title.contains("Seeking Freelancer") {
        Some(ThreadType::Freelancer)
    } else if title.contains("Who is hiring") {
        Some(ThreadType::Fulltime)
    } else {
        None
    }
}


fn parse_date(title: &str) -> Option<Date> {
    lazy_static! {
        static ref RE: Regex = Regex::new(r"\((\w+) (\d+)\)").unwrap();
    }

    let caps: Captures = RE.captures(title)?;
    let month = caps.get(1)
        .and_then(|m| MONTHS.iter().position(|s| **s == m.as_str()[0..3]));

    let year = caps.get(2)
        .and_then(|m| u16::from_str(&m.as_str()).ok());

    Some(Date {
        month: month? as u32,
        year: year? as i32,
    })
}

fn get_item(client: &Client, id: Id) -> reqwest::Result<Item> {
    client.get(&format!("{}/item/{}.json", BASE, id))
        .send()?.json()
}

fn item_to_thread(item: Item) -> Option<Thread> {
    if item.typ != "story"{
        return None;
    }

    let title = item.title?;

    Some(Thread {
        id: item.id,
        thread_type: parse_type(&title)?,
        date: parse_date(&title)?,
        comments: item.kids.unwrap_or(vec![]),
    })
}

fn item_to_comment(item: &Item) -> Option<Comment> {
    Some(Comment {
        id: item.id,
        level: 0,
        html: item.text.clone()?,
        submitter: item.by.clone()?,
        url: format!("https://news.ycombinator.com/item?id={}", item.id),
        time: item.time,
    })
}

fn expand_comments(client: &Client, thread: &Thread) -> Vec<Comment> {
    thread.comments.par_iter()
        .map(|id|
            get_item(client, *id)
                .map(|i| Some(i))
                .unwrap_or_else(|err| {
                    error!("Failed on comment {}: {}", id, err);
                    None
                }).and_then(|i| item_to_comment(&i)))
        .filter(|c| c.is_some())
        .map(|c| c.unwrap())
        .collect()
}

fn parse_thread_list_element(s1: &str, s2: &str) -> Option<ThreadListElement> {
    lazy_static! {
            static ref RE: Regex = Regex::new(r"(\w+) (\d+) &mdash; (\w+)").unwrap();
        }

    let captures = RE.captures(s1)?;

    Some(ThreadListElement {
        id: u64::from_str(s2).ok()?,
        thread_type: match &captures[3] {
            "fulltime" => ThreadType::Fulltime,
            "freelancers" => ThreadType::Freelancer,
            _ => return None,
        },
        date: Date {
            month: MONTHS.iter().position(|s| **s == captures[1])? as u32,
            year: i32::from_str(&captures[2]).ok()?,
        }
    })
}

fn process(out_dir: &Path) -> reqwest::Result<()> {
    info!("Writing out to {:?}", out_dir);
    let client = Client::builder()
        .redirect(RedirectPolicy::limited(10))
        .build()?;
    let user: User = client.get(&format!("{}/user/{}.json", BASE, USER))
        .send()?
        .json()?;

    let threads: Vec<Thread> = user.submitted[..10].par_iter()
        .map(|id| {
            get_item(&client, *id)
                .map(|i| Some(i))
                .unwrap_or_else(|err| {
                    error!("Failed on {}: {}", id, err);
                    None
                })
        })
        .map(|item| {
            item.and_then(|item| item_to_thread(item))
        }).filter(|t| t.is_some())
        .map(|t| t.unwrap())
        .filter(|t| t.date.is_current())
        .collect();

    for thread in &threads {
        info!("Processing {:?} {} {}", thread.thread_type, &MONTHS[thread.date.month as usize], thread.date.year);
        let comments: HashMap<String, Comment> = expand_comments(&client, &thread)
            .into_iter().map(|c| (format!("{}", c.id), c))
            .collect();

        let path = out_dir.join(format!("comments-{}.json", thread.id));

        fs::write(path, serde_json::to_string(&comments).unwrap()).unwrap();
    }

    let thread_list: Vec<Vec<String>> = client.get("http://hnhiring.me/data/threads.json")
        .send()?.json()?;


    let mut thread_map: HashMap<(Date, ThreadType), ThreadListElement> = thread_list.iter()
        .filter(|p| p.len() == 2)
        .map(|p| parse_thread_list_element(&p[0], &p[1]))
        .filter(|p| p.is_some())
        .map(|p| p.unwrap())
        .map(|p| ((p.date, p.thread_type), p))
        .collect();

    for thread in threads {
        thread_map.insert((thread.date, thread.thread_type), ThreadListElement {
            id: thread.id,
            thread_type: thread.thread_type,
            date: thread.date,
        });
    }

    let mut thread_list: Vec<ThreadListElement> = thread_map.values().map(|f| f.clone()).collect();
    thread_list.sort_by(|a, b|
        a.date.year.cmp(&b.date.year)
            .then(a.date.month.cmp(&b.date.month))
            .reverse()
            .then(a.thread_type.cmp(&b.thread_type).reverse()));

    let thread_list: Vec<Vec<String>> = thread_list.iter().map(|el| vec![
        format!("{} {} &mdash; {:?}", MONTHS[el.date.month as usize], el.date.year, el.thread_type),
        format!("{}", el.id),
    ]).collect();

    let path = out_dir.join(format!("threads.json"));
    fs::write(path, serde_json::to_string(&thread_list).unwrap()).unwrap();

    Ok(())
}
