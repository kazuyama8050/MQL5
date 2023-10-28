import os, sys
from argparse import ArgumentParser
from datetime import date, timedelta
import configparser
import traceback

current_script_path = os.path.abspath(__file__)
app_home = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
app_dir = os.path.abspath(os.path.join(current_script_path, "../../"))
project_dir = os.path.abspath(os.path.join(current_script_path, "../../../"))

sys.path.append(os.path.join(project_dir, "lib"))

from mail_handler import MailHandler

def get_options():
    usage = "usage: %prog (Argument-1) [options]"
    parser = ArgumentParser(usage=usage)
    parser.add_argument("-d", "--dir", dest="dir", action="store", help="dir", default="", type=str)
    parser.add_argument("-t", "--target", dest="target", action="store", help="target", default="today", type=str)
    return parser.parse_args()

options = get_options()
credential_conf = configparser.ConfigParser()
credential_conf.read(os.path.join(project_dir, "credentials.conf"))

def main():
    try:
        dir = options.dir
        target = options.target
        if os.path.exists(dir) == False:
            print("ディレクトリが存在しない, {}".format(dir));
            return
        
        if target == "today":
            target_date = date.today()
        elif target == "yesterday":
            target_date = date.today() - timedelta(days=1)
        else:
            target_date = date.today()
                        
        filename = target_date.strftime("%Y%m%d") + ".log"
        filepath = os.path.join(dir, filename)
        if os.path.exists(filepath) == False:
            print("ログファイルが存在しない, {}".format(filepath))
            return
        
        mail_body_msg = ""
        with open(filepath, "r", encoding="utf-16") as f:
            for line in f.readlines():
                if "ERROR" in line or "WARN" in line:
                    a, b, log_time, trade_target, log_msg = line.split("\t")
                    log_datetime = target_date.strftime("%Y-%m-%d") + " " + log_time.split(".")[0]
                    mail_body_msg = mail_body_msg + trade_target + "\t" + log_datetime + "\n" + log_msg + "\n-------------------\n"
        
        if mail_body_msg == "":
            print("no warn or error log in {}".format(filepath))
            return
        
        mail_body_template = MailHandler.read_mail_body_template(os.path.join(app_dir, "mail", "log_error_template.txt"))
        mail_body = mail_body_template.format(
            date = target_date.strftime("%Y-%m-%d"),
            body = mail_body_msg
        )
        MailHandler.send_mail(credential_conf.get("mail", "to_address"), "ログ監視通知", mail_body)
        
        print("send mail done")
    except Exception as e:
        print(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    print("start!")
    main()
    print("end!")